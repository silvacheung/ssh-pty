package host

import (
	"context"
	"io"
)

var pty = make(map[string]func(ctx context.Context, runtime Runtime) Pty)

func init() {
	SetPTY("xterm", NewXterm)
}

func SetPTY(name string, fn func(ctx context.Context, runtime Runtime) Pty) {
	pty[name] = fn
}

func GetPTY(name string) func(ctx context.Context, runtime Runtime) Pty {
	return pty[name]
}

type Pty interface {
	Shell(ctx context.Context) Shell
	Sftp(ctx context.Context) Sftp
}

type Shell interface {
	Stdin(func(ctx context.Context, stdin io.Writer)) Shell
	Stdout(func(ctx context.Context, stdin io.Writer, buf []byte)) Shell
	Stderr(func(ctx context.Context, stdin io.Writer, buf []byte)) Shell
	Exited(func(ctx context.Context, code int, out []byte) error) error
}

type Sftp interface {
	Copy(ctx context.Context, src, dst string) error
}
