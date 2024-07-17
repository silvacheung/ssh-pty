package host

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"errors"
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
	key := fmt.Sprintf("%s@%s(%s)", host.Username(ctx), host.Address(ctx), host.Hostname(ctx))
	val, ok := xterm.Load(key)
	if ok && val != nil {
		xt = val.(*Xterm)
		if err := xt.ping(); err == nil {
			return xt
		}
	}

	xt = &Xterm{ctx: ctx, host: host}
	authMethods := make([]ssh.AuthMethod, 0, 2)
	if pwd := xt.host.Password(xt.ctx); len(pwd) > 0 {
		authMethods = append(authMethods, ssh.Password(pwd))
	}
	// cmd: ssh-keygen -m pem -t rsa -b 4096 -N "" -C "k8s-pty" -f ~/.ssh/id_rsa
	// cmd: cat /root/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
	// cmd: chmod 600 ~/.ssh/authorized_keys
	if KEY := xt.host.PrivateKEY(xt.ctx); len(KEY) > 0 {
		pem, bErr := base64.StdEncoding.DecodeString(KEY)
		if bErr != nil {
			file, fErr := os.Open(KEY)
			if fErr != nil {
				xt.err = errors.Join(bErr, fErr)
				return xt
			}
			defer func() { _ = file.Close() }()
			if pem, fErr = io.ReadAll(file); fErr != nil {
				xt.err = errors.Join(bErr, fErr)
				return xt
			}
		}

		var signer ssh.Signer
		switch phrase := xt.host.Passphrase(ctx); {
		case len(phrase) <= 0:
			signer, xt.err = ssh.ParsePrivateKey(pem)
		default:
			signer, xt.err = ssh.ParsePrivateKeyWithPassphrase(pem, []byte(phrase))
		}

		if xt.err != nil {
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

	if xt.err == nil {
		xterm.Store(key, xt)
	}

	return xt
}

func (xt *Xterm) Shell(ctx context.Context) Shell {
	return &XtermShell{xterm: xt, ctx: ctx, buf: new(bytes.Buffer)}
}

func (xt *Xterm) Sftp(ctx context.Context) Sftp {
	return &XtermSftp{xterm: xt}
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
	defer session.Close()
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
	xterm  *Xterm
	ctx    context.Context
	buf    *bytes.Buffer
	stdin  func(ctx context.Context, stdin io.Writer)
	stdout func(ctx context.Context, stdin io.Writer, buf []byte)
	stderr func(ctx context.Context, stdin io.Writer, buf []byte)
	exited func(ctx context.Context, code int, out []byte) error
}

func (xt *XtermShell) Stdin(fn func(ctx context.Context, stdin io.Writer)) Shell {
	xt.stdin = fn
	return xt
}

func (xt *XtermShell) Stdout(fn func(ctx context.Context, stdin io.Writer, buf []byte)) Shell {
	xt.stdout = fn
	return xt
}

func (xt *XtermShell) Stderr(fn func(ctx context.Context, stdin io.Writer, buf []byte)) Shell {
	xt.stderr = fn
	return xt
}

func (xt *XtermShell) Exited(fn func(ctx context.Context, code int, out []byte) error) error {
	if xt.xterm.err != nil {
		return xt.xterm.err
	}
	if xt.exited = fn; xt.exited == nil {
		xt.exited = func(ctx context.Context, code int, out []byte) error { return nil }
	}
	if xt.stderr == nil {
		xt.stderr = func(ctx context.Context, stdin io.Writer, buf []byte) {}
	}
	if xt.stdout == nil {
		xt.stdout = func(ctx context.Context, stdin io.Writer, buf []byte) {}
	}
	if xt.stdin == nil {
		return fmt.Errorf("stdin notfound")
	}
	if xt.stdin(xt.ctx, xt.buf); xt.buf.Len() == 0 {
		return fmt.Errorf("stdin empty")
	}

	session, err := xt.xterm.shell.NewSession()
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

	stdin, err := session.StdinPipe()
	if err != nil {
		return err
	}

	stdout, err := session.StdoutPipe()
	if err != nil {
		return err
	}

	stderr, err := session.StderrPipe()
	if err != nil {
		return err
	}

	cmd := xt.buf.String()
	xt.buf.Reset()
	exitCode := 0
	if err = session.Start(cmd); err != nil {
		if exitErr, ok := err.(*ssh.ExitError); ok {
			exitCode = exitErr.ExitStatus()
			return xt.exited(xt.ctx, exitCode, xt.buf.Bytes())
		}
		return err
	}

	// stderr
	go xt.reader(xt.ctx, stderr, func(ctx context.Context, buf []byte) {
		xt.stderr(ctx, stdin, buf)
	})

	// stdout
	xt.reader(xt.ctx, stdout, func(ctx context.Context, buf []byte) {
		xt.stdout(ctx, stdin, buf)
		if buf[len(buf)-1] == '\n' {
			xt.buf.Write(buf)
		}
	})

	if err = session.Wait(); err != nil {
		if exitErr, ok := err.(*ssh.ExitError); ok {
			exitCode = exitErr.ExitStatus()
			return xt.exited(xt.ctx, exitCode, xt.buf.Bytes())
		}
		return err
	}

	return xt.exited(xt.ctx, exitCode, xt.buf.Bytes())
}

func (xt *XtermShell) reader(ctx context.Context, r io.Reader, fn func(ctx context.Context, buf []byte)) {
	if fn == nil {
		fn = func(ctx context.Context, buf []byte) {}
	}

	buf := make([]byte, 0, 1024)
	reader := bufio.NewReader(r)

	for {
		if e := ctx.Err(); e != nil {
			return
		}

		b, e := reader.ReadByte()
		if e != nil {
			break
		}

		buf = append(buf, b)
		fn(ctx, buf)
		if b == '\n' {
			buf = buf[:0]
			continue
		}
	}
}

type XtermSftp struct {
	xterm *Xterm
}

// Copy copy src file or dir to dst dir
func (xt *XtermSftp) Copy(ctx context.Context, src, dst string) error {
	if xt.xterm.err != nil {
		return xt.xterm.err
	}

	hostname := xt.xterm.host.Hostname(ctx)
	return filepath.WalkDir(src, func(p string, d fs.DirEntry, e error) error {
		if d == nil {
			return nil
		}
		file := filepath.ToSlash(strings.TrimPrefix(p, filepath.Dir(src)))
		file = path.Join(dst, file)
		if d.IsDir() {
			fmt.Printf("创建远程目录[%s]:%s -> %s\n", hostname, p, file)
			return xt.xterm.sftp.MkdirAll(file)
		}

		fmt.Printf("传输远程文件[%s]:%s -> %s\n", hostname, p, file)
		dstFile, err := xt.xterm.sftp.Create(file)
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
