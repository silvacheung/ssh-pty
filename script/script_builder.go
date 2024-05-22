package script

import (
	"bytes"
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
	"io"
	"os"
	"path/filepath"
	"text/template"
)

type Template struct {
	ctx           context.Context
	dir, filename string
	template      []byte
	config        *conf.Config
	err           error
}

func NewTemplate(ctx context.Context) Builder {
	return &Template{ctx: ctx}
}

func (b *Template) File(file string) Builder {
	f, e := os.Open(file)
	if b.err = e; b.err != nil {
		b.err = fmt.Errorf("open file: %w", b.err)
		return b
	}
	if b.template, b.err = io.ReadAll(f); b.err != nil {
		b.err = fmt.Errorf("read file: %w", b.err)
	}
	b.dir, b.filename = filepath.Split(file)
	return b
}

func (b *Template) Config(config *conf.Config) Builder {
	b.config = config
	return b
}

func (b *Template) Build(ctx context.Context, h host.Runtime, fn func(ctx context.Context, err error)) {
	hostname := h.Hostname(ctx)
	workdir := h.Workdir(ctx)

	if b.err != nil {
		fn(ctx, b.err)
		return
	}

	// 定义函数
	funcMap := template.FuncMap{
		"get": b.config.Get,
		"has": b.config.IsSet,
		"not": func(key string) bool { return !b.config.IsSet(key) },
	}

	// 渲染模板
	file := filepath.Join(b.dir, b.filename)
	fmt.Printf("渲染脚本文件[%s]:%s\n", hostname, file)
	tmpl, err := template.New(b.filename).Funcs(funcMap).Parse(string(b.template))
	if err != nil {
		fn(ctx, fmt.Errorf("%s template parse: %w", hostname, err))
		return
	}

	buffer := new(bytes.Buffer)
	if err = tmpl.Execute(buffer, b.config.AllSettings()); err != nil {
		fn(ctx, fmt.Errorf("%s template exec: %w", hostname, err))
		return
	}

	// 生成文件
	tempDir := filepath.Join(os.TempDir(), "ssh-pty", hostname)
	if err = os.MkdirAll(tempDir, 0666); err != nil {
		fn(ctx, fmt.Errorf("%s make tempdir: %w", hostname, err))
		return
	}

	tempFile := filepath.Join(tempDir, b.filename)
	fmt.Printf("生成脚本文件[%s]:%s -> %s\n", hostname, file, tempFile)
	if err = os.WriteFile(tempFile, buffer.Bytes(), 0666); err != nil {
		fn(ctx, fmt.Errorf("%s write tempfile: %w", hostname, err))
		return
	}

	// 传输脚本文件
	err = h.PTY(ctx, "xterm").Sftp(ctx).Copy(ctx, tempFile, workdir)
	if err != nil {
		fn(ctx, fmt.Errorf("%s sftp: %w", hostname, err))
		return
	}

	// 渲染执行成功
	fn(ctx, nil)
}
