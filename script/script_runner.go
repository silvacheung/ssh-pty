package script

import (
	"bytes"
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/host"
	"path/filepath"
)

type SSHPty struct {
	ctx context.Context
}

func NewSSHPty(ctx context.Context) Runner {
	return &SSHPty{ctx: ctx}
}

func (r *SSHPty) Run(ctx context.Context, filename string, h host.Runtime) error {
	// 获取指定文件
	workdir := h.Workdir(ctx)
	_, file := filepath.Split(filename)

	// 生成执行命令
	cmd := fmt.Sprintf("chmod +x %s/%s && %s/%s", workdir, file, workdir, file)
	stdin := bytes.NewBufferString(cmd)

	// 远程执行命令
	fmt.Println("执行脚本文件 ->", cmd)
	return h.PTY(ctx, "xterm").Shell(ctx).
		Stdout(func(ctx context.Context, stdin *bytes.Buffer, line string) error {
			fmt.Println(line)
			return nil
		}).
		Stdin(stdin, func(ctx context.Context, out *bytes.Buffer, code int) error {
			if code != 0 {
				return fmt.Errorf("ssh pty exitcode: (%d) %s", code, out)
			}
			return nil
		})
}
