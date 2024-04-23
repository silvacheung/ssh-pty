package host

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

var xterm = new(sync.Map)

type Xterm struct {
	ctx   context.Context
	host  Runtime
	shell *ssh.Client
	sftp  *sftp.Client
	err   error
}

func NewXterm(ctx context.Context, host Runtime) Pty {
	var xt *Xterm
	key := fmt.Sprintf("%s(%s)", host.Hostname(ctx), host.Address(ctx))
	val, ok := xterm.Load(key)
	if ok && val != nil {
		xt = val.(*Xterm)
		if err := xt.ping(); err == nil {
			return xt
		}
	}

	xt = &Xterm{ctx: ctx, host: host}
	authMethods := make([]ssh.AuthMethod, 0, 2)
	if pass := xt.host.Password(xt.ctx); len(pass) > 0 {
		authMethods = append(authMethods, ssh.Password(pass))
	}
	if KEY := xt.host.PrivateKEY(xt.ctx); len(KEY) > 0 {
		signer, err := ssh.ParsePrivateKey([]byte(KEY))
		if err != nil {
			xt.err = err
			return xt
		}
		authMethods = append(authMethods, ssh.PublicKeys(signer))
	}
	endpoint := xt.host.Address(xt.ctx) + ":" + xt.host.Port(xt.ctx)
	xt.shell, xt.err = ssh.Dial("tcp", endpoint, &ssh.ClientConfig{
		Config:          ssh.Config{},
		User:            xt.host.Username(xt.ctx),
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
		Timeout:         time.Second * 10,
	})
	if xt.err == nil {
		xt.sftp, xt.err = sftp.NewClient(xt.shell)
	}

	return xt
}

func (xt *Xterm) Shell(ctx context.Context) Shell {
	return &XtermShell{Xterm: xt, output: new(bytes.Buffer)}
}

func (xt *Xterm) Sftp(ctx context.Context) Sftp {
	return &XtermSftp{Xterm: xt}
}

func (xt *Xterm) ping() error {
	if xt.shell == nil {
		return fmt.Errorf("xterm ping: ssh client nil")
	}
	if xt.err != nil {
		return xt.err
	}
	session, err := xt.shell.NewSession()
	if err != nil {
		return err
	}
	pong, err := session.Output(`echo "pong"`)
	if err != nil {
		return err
	}
	if string(pong) != "pong" {
		return fmt.Errorf("xterm ping: not echo pong")
	}
	return nil
}

type XtermShell struct {
	*Xterm
	output   *bytes.Buffer
	stdoutFn func(ctx context.Context, stdin *bytes.Buffer, line string) error
	stderrFn func(ctx context.Context, stdin *bytes.Buffer, line string)
}

func (xt *XtermShell) Stdout(fn func(ctx context.Context, stdin *bytes.Buffer, line string) error) Shell {
	xt.stdoutFn = fn
	return xt
}

func (xt *XtermShell) Stderr(fn func(ctx context.Context, stdin *bytes.Buffer, line string)) Shell {
	xt.stderrFn = fn
	return xt
}

func (xt *XtermShell) Stdin(stdin *bytes.Buffer, exited func(ctx context.Context, out *bytes.Buffer, code int) error) (err error) {
	if exited == nil {
		exited = func(ctx context.Context, out *bytes.Buffer, code int) error { return nil }
	}

	if xt.err != nil {
		return xt.err
	}

	session, err := xt.shell.NewSession()
	if err != nil {
		return err
	}
	defer session.Close()

	if err = session.RequestPty("xterm", 100, 50, ssh.TerminalModes{
		ssh.ECHO:          0,     // disable echoing
		ssh.TTY_OP_ISPEED: 14400, // input  speed = 14.4kbaud
		ssh.TTY_OP_OSPEED: 14400, // output speed = 14.4kbaud
	}); err != nil {
		return err
	}

	stdoutPIP, err := session.StdoutPipe()
	if err != nil {
		return err
	}

	stderrPIP, err := session.StderrPipe()
	if err != nil {
		return err
	}

	var exitCode int
	if err = session.Start(strings.TrimSpace(stdin.String())); err != nil {
		if exitErr, ok := err.(*ssh.ExitError); ok {
			exitCode = exitErr.ExitStatus()
			return exited(xt.ctx, xt.output, exitCode)
		}
		return err
	}

	// stdin
	stdin.Reset()
	session.Stdin = stdin

	// stderr
	if xt.stderrFn != nil {
		go func() {
			reader := bufio.NewReader(stderrPIP)
			for {
				line, err := reader.ReadString('\n')
				if err != nil {
					if err != io.EOF {
						fmt.Println(err)
					}
					break
				}

				line = strings.TrimPrefix(line, fmt.Sprintf("[sudo] password for %s:", xt.host.Username(xt.ctx)))
				line = strings.TrimSpace(line)
				if xt.stderrFn != nil {
					xt.stderrFn(xt.ctx, stdin, line)
				}
			}
		}()
	}

	// stdout
	stdoutReader := bufio.NewReader(stdoutPIP)
	for {
		line, err := stdoutReader.ReadString('\n')
		if err != nil {
			if err != io.EOF {
				fmt.Println(err)
			}
			break
		}

		// FIXME 这里使用逐行读取不能做到自动输入密码，因为输入密码的那一行还没有换行，需要做成按缓冲区读取
		if (strings.HasPrefix(line, "[sudo] password for ") ||
			strings.HasPrefix(line, "Password")) &&
			strings.HasSuffix(line, ": ") {
			if _, err = stdin.Write([]byte(xt.host.Password(xt.ctx) + "\n")); err != nil {
				break
			}
		}

		line = strings.TrimPrefix(line, fmt.Sprintf("[sudo] password for %s:", xt.host.Username(xt.ctx)))
		line = strings.TrimSpace(line)
		xt.output.WriteString(line)
		if xt.stdoutFn != nil {
			if err = xt.stdoutFn(xt.ctx, stdin, line); err != nil {
				return err
			}
		}
	}

	if err = session.Wait(); err != nil {
		if exitErr, ok := err.(*ssh.ExitError); ok {
			exitCode = exitErr.ExitStatus()
			return exited(xt.ctx, xt.output, exitCode)
		}
		return err
	}

	return exited(xt.ctx, xt.output, exitCode)
}

type XtermSftp struct {
	*Xterm
}

func (xt *XtermSftp) CopyFile(ctx context.Context, local, remote string) (err error) {
	if xt.err != nil {
		return xt.err
	}

	return filepath.WalkDir(local, func(p string, d fs.DirEntry, e error) error {
		file := filepath.ToSlash(strings.TrimPrefix(p, filepath.Dir(local)))
		file = path.Join(remote, file)
		if d.IsDir() {
			fmt.Println("创建远程目录:", file)
			return xt.sftp.MkdirAll(file)
		}

		fmt.Println("传输远程文件:", file)
		dstFile, err := xt.sftp.Create(file)
		if err != nil {
			return err
		}
		defer dstFile.Close()

		srcFile, err := os.Open(p)
		if err != nil {
			return err
		}
		defer srcFile.Close()

		_, err = io.Copy(dstFile, srcFile)
		return err
	})
}
