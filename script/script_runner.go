package script

import (
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/host"
	"io"
	"path/filepath"
	"strings"
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

	// 远程执行命令
	hostname := h.Hostname(ctx)
	fmt.Printf("执行脚本文件[%s]: %s\n", hostname, cmd)
	return h.PTY(ctx, "xterm").Shell(ctx).
		Stdin(func(ctx context.Context, stdin io.Writer) {
			_, _ = stdin.Write([]byte(cmd))
		}).
		Stdout(func(ctx context.Context, stdin io.Writer, buf []byte) {
			// 输入密码
			line := string(buf)
			if (strings.HasPrefix(line, "[sudo] password for ") ||
				strings.HasPrefix(line, "Password")) &&
				strings.HasSuffix(line, ": ") {
				_, _ = stdin.Write([]byte(h.Password(ctx) + "\n"))
			}
			// 打印完整行
			if buf[len(buf)-1] == '\n' {
				fmt.Print(string(buf))
			}
		}).
		Exited(func(ctx context.Context, code int, out []byte) error {
			if code != 0 {
				return fmt.Errorf("%s exitcode: (%d) %s", hostname, code, string(out))
			}
			return nil
		})
}
