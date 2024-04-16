package script

import (
	"bytes"
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/host"
	"os"
	"path/filepath"
	"text/template"
)

type Template struct {
	ctx      context.Context
	filename string
	template string
	metadata Metadata
}

func NewTemplate(ctx context.Context) Builder {
	return &Template{ctx: ctx}
}

func (b *Template) Filename(filename string) Builder {
	b.filename = filename
	return b
}

func (b *Template) Template(template string) Builder {
	b.template = template
	return b
}

func (b *Template) Metadata(metadata Metadata) Builder {
	b.metadata = metadata
	return b
}

func (b *Template) Building(ctx context.Context, h host.Runtime, fn func(ctx context.Context, err error)) {
	hostname := h.Hostname(ctx)
	if fn == nil {
		fn = func(ctx context.Context, err error) {
			fmt.Println(fmt.Errorf("%s building: %w", hostname, err))
		}
	}

	// 文件信息
	workdir := h.Workdir(ctx)
	_, filename := filepath.Split(b.filename)
	remoteFile := workdir + "/" + filename

	// 渲染模板
	fmt.Printf("渲染脚本文件[%s]:%s\n", hostname, remoteFile)
	tpl, err := template.New(b.filename).Parse(b.template)
	if err != nil {
		fn(ctx, fmt.Errorf("%s template parse: %w", hostname, err))
		return
	}

	buffer := new(bytes.Buffer)
	if err = tpl.Execute(buffer, b.metadata); err != nil {
		fn(ctx, fmt.Errorf("%s template exec: %w", hostname, err))
		return
	}

	// 生成文件
	tempFile := os.TempDir() + "/ssh-pty-" + hostname + "-" + filename
	//if err := os.Remove(tempFile); err != nil && !os.IsNotExist(err) {
	//	fn(ctx, fmt.Errorf("%s remove temp file: %w", hostname, err))
	//	return
	//}
	fmt.Printf("生成脚本文件[%s]:%s\n", hostname, tempFile)
	if err = os.WriteFile(tempFile, buffer.Bytes(), 0666); err != nil {
		fn(ctx, fmt.Errorf("%s write temp file: %w", hostname, err))
		return
	}

	// 创建文件夹
	buffer.Reset()
	buffer.WriteString("mkdir -p " + workdir)
	err = h.PTY(ctx, "xterm").Shell(ctx).Stdin(buffer, func(ctx context.Context, out *bytes.Buffer, code int) error {
		if code != 0 {
			return fmt.Errorf("%s exitcode: %d %s", hostname, code, out.String())
		}
		return nil
	})

	if err != nil {
		fn(ctx, fmt.Errorf("%s pty shell: %w", hostname, err))
		return
	}

	fmt.Printf("拷贝脚本文件[%s]: %s --> %s\n", hostname, tempFile, remoteFile)
	err = h.PTY(ctx, "xterm").Sftp(ctx).CopyFile(ctx, tempFile, remoteFile)
	if err != nil {
		fn(ctx, fmt.Errorf("%s pty sftp: %w", hostname, err))
		return
	}

	fn(ctx, nil)
}
