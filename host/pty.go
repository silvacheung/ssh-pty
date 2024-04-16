package host

import (
	"bytes"
	"context"
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
	Stdin(stdin *bytes.Buffer, exited func(ctx context.Context, out *bytes.Buffer, code int) error) error
	Stdout(func(ctx context.Context, stdin *bytes.Buffer, line string) error) Shell
	Stderr(func(ctx context.Context, stdin *bytes.Buffer, line string)) Shell
}

type Sftp interface {
	CopyFile(ctx context.Context, local, remote string) error
}
