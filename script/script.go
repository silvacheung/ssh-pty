package script

import (
	"context"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
)

type Metadata map[string]any

func (md Metadata) SetConfigs(ctx context.Context, config *conf.Config) {
	md["Configs"] = config.Metadata["configs"]
}

func (md Metadata) SetThisHost(ctx context.Context, this host.Runtime) {
	md["Host"] = map[string]any{
		"NetIF":      this.NetIF(ctx),
		"Workdir":    this.Workdir(ctx),
		"Hostname":   this.Hostname(ctx),
		"Address":    this.Address(ctx),
		"Internal":   this.Internal(ctx),
		"Port":       this.Port(ctx),
		"Username":   this.Username(ctx),
		"Password":   this.Password(ctx),
		"PrivateKEY": this.PrivateKEY(ctx),
		"Values":     this.Values(ctx),
	}
}

func (md Metadata) SetAllHosts(ctx context.Context, hosts ...host.Runtime) {
	all := make([]map[string]any, 0, len(hosts))
	for _, h := range hosts {
		if h == nil {
			continue
		}
		all = append(all, map[string]any{
			"NetIF":      h.NetIF(ctx),
			"Workdir":    h.Workdir(ctx),
			"Hostname":   h.Hostname(ctx),
			"Address":    h.Address(ctx),
			"Internal":   h.Internal(ctx),
			"Port":       h.Port(ctx),
			"Username":   h.Username(ctx),
			"Password":   h.Password(ctx),
			"PrivateKEY": h.PrivateKEY(ctx),
			"Values":     h.Values(ctx),
		})
	}
	md["Hosts"] = all
}

// Runtime 脚本运行时
type Runtime interface {
	Builder(ctx context.Context, name string) Builder
	Runner(ctx context.Context, name string) Runner
}

// Builder 脚本构造器
type Builder interface {
	// Filename 构建后的脚本名称
	Filename(filename string) Builder
	// Template 脚本模板文本
	Template(template string) Builder
	// Metadata 脚本模板数据
	Metadata(metadata Metadata) Builder
	// Building 构建脚本并将脚本存放在Filepath
	Building(ctx context.Context, h host.Runtime, fn func(ctx context.Context, err error))
}

// Runner 脚本执行器
type Runner interface {
	Run(ctx context.Context, h host.Runtime, filename string) error
}
