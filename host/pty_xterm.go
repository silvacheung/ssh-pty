package host

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
	"io"
	"os"
	"strings"
	"sync"
	"time"
)

type Xterm struct {
	ctx     context.Context
	mux     *sync.Mutex
	runtime Runtime
	client  *ssh.Client
	sftp    *sftp.Client
}

func NewXterm(ctx context.Context, runtime Runtime) Pty {
	return &Xterm{ctx: ctx, mux: new(sync.Mutex), runtime: runtime}
}

func (xt *Xterm) Shell(ctx context.Context) Shell {
	return &XtermShell{Xterm: xt, output: new(bytes.Buffer)}
}

func (xt *Xterm) Sftp(ctx context.Context) Sftp {
	return &XtermSftp{Xterm: xt}
}

func (xt *Xterm) connTo(ctx context.Context) (err error) {
	xt.mux.Lock()
	defer xt.mux.Unlock()
	if xt.client == nil || xt.sftp == nil {
		authMethods := make([]ssh.AuthMethod, 0, 2)
		if len(xt.runtime.Password(xt.ctx)) > 0 {
			authMethods = append(authMethods, ssh.Password(xt.runtime.Password(xt.ctx)))
		}

		if len(xt.runtime.PrivateKEY(xt.ctx)) > 0 {
			signer, err := ssh.ParsePrivateKey([]byte(xt.runtime.PrivateKEY(xt.ctx)))
			if err != nil {
				return err
			}
			authMethods = append(authMethods, ssh.PublicKeys(signer))
		}

		endpoint := xt.runtime.Address(xt.ctx) + ":" + xt.runtime.Port(xt.ctx)
		xt.client, err = ssh.Dial("tcp", endpoint, &ssh.ClientConfig{
			Config:          ssh.Config{},
			User:            xt.runtime.Username(xt.ctx),
			Auth:            authMethods,
			HostKeyCallback: ssh.InsecureIgnoreHostKey(),
			Timeout:         time.Second * 10,
		})
		if err != nil {
			return err
		}

		xt.sftp, err = sftp.NewClient(xt.client)
	}

	return err
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

	if err = xt.connTo(xt.ctx); err != nil {
		return err
	}

	session, err := xt.client.NewSession()
	if err != nil {
		return err
	}

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

				line = strings.TrimPrefix(line, fmt.Sprintf("[sudo] password for %s:", xt.runtime.Username(xt.ctx)))
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
			if _, err = stdin.Write([]byte(xt.runtime.Password(xt.ctx) + "\n")); err != nil {
				break
			}
		}

		line = strings.TrimPrefix(line, fmt.Sprintf("[sudo] password for %s:", xt.runtime.Username(xt.ctx)))
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
	if err = xt.connTo(xt.ctx); err != nil {
		return err
	}

	// read src file
	src, err := os.Open(local)
	if err != nil {
		return err
	}
	defer src.Close()

	// src stat
	stat, err := src.Stat()
	if err != nil {
		return err
	}

	// the dst file mod will be 0666
	dst, err := xt.sftp.Create(remote)
	if err != nil {
		return err
	}
	defer dst.Close()

	// dst chmod
	if err = dst.Chmod(stat.Mode()); err != nil {
		return err
	}

	// copy
	_, err = io.Copy(dst, src)
	return
}
