package script

import (
	"context"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
)

// Runtime 脚本运行时
type Runtime interface {
	Builder(ctx context.Context, name string) Builder
	Runner(ctx context.Context, name string) Runner
}

// Builder 脚本构造器
type Builder interface {
	// File 脚本文件
	File(file string) Builder
	// Config 配置文件
	Config(config *conf.Config) Builder
	// Build 构建脚本并将脚本存放在Filepath
	Build(ctx context.Context, h host.Runtime, fn func(ctx context.Context, err error))
}

// Runner 脚本执行器
type Runner interface {
	Run(ctx context.Context, h host.Runtime, file string) error
}
