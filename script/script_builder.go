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
	if fn == nil {
		fn = func(ctx context.Context, err error) {
			fmt.Println(err)
		}
	}

	// 文件信息
	_, filename := filepath.Split(b.filename)
	remoteFile := h.Workdir(ctx) + "/" + filename

	// 渲染模板
	fmt.Println("渲染脚本文件 ->", remoteFile)
	tpl, err := template.New(b.filename).Parse(b.template)
	if err != nil {
		fn(ctx, err)
		return
	}

	buffer := new(bytes.Buffer)
	if err = tpl.Execute(buffer, b.metadata); err != nil {
		fn(ctx, err)
		return
	}

	// 生成文件
	tempFile := os.TempDir() + "/" + filename
	if err := os.Remove(tempFile); err != nil && !os.IsNotExist(err) {
		fn(ctx, err)
		return
	}
	if err = os.WriteFile(tempFile, buffer.Bytes(), 0666); err != nil {
		fn(ctx, err)
		return
	}

	fn(ctx, h.PTY(ctx, "xterm").
		Sftp(ctx).
		CopyFile(ctx, tempFile, remoteFile))
}
