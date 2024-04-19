package script

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
	"io"
	"net/url"
	"os"
	"strings"
	"sync"
)

type Metadata map[string]any

func (md Metadata) Clone(ctx context.Context) Metadata {
	clone := make(Metadata, len(md))
	for k, v := range md {
		clone[k] = v
	}
	return clone
}

func (md Metadata) SetConfigs(ctx context.Context, config *conf.Config) Metadata {
	md["Configs"] = config.Metadata["configs"]
	return md
}

func (md Metadata) SetThisHost(ctx context.Context, this host.Runtime) Metadata {
	if this == nil {
		return md
	}
	clone := md.Clone(ctx)
	clone["Host"] = map[string]any{
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
	return clone
}

func (md Metadata) SetAllHosts(ctx context.Context, hosts ...host.Runtime) Metadata {
	clone := md.Clone(ctx)
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
	clone["Hosts"] = all
	return clone
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
	Run(ctx context.Context, filename string, h host.Runtime) error
}

type Executor struct {
	runtime  Runtime
	config   *conf.Config
	hosts    []host.Runtime
	metadata Metadata
	parallel bool
}

type scriptInfo struct {
	file string
	tmpl string
}

func NewExecutor() *Executor {
	return &Executor{metadata: make(map[string]any)}
}

func (exec *Executor) SetRuntime(runtime Runtime) *Executor {
	exec.runtime = runtime
	return exec
}

func (exec *Executor) SetConfig(config *conf.Config) *Executor {
	exec.config = config
	return exec
}

func (exec *Executor) SetParallel(parallel bool) *Executor {
	exec.parallel = parallel
	return exec
}

func (exec *Executor) Executing(ctx context.Context) error {
	// 配置文件数据
	cfgHosts := exec.config.GetStringSlice("hosts")
	cfgScripts := exec.config.GetStringSlice("scripts")
	cfgSpecial := exec.config.GetStringMapStringSlice("special")
	//cfgSftp := exec.config.GetStringMapStringSlice("sftp")

	// 读取执行主机
	hosts := make([]host.Runtime, 0, len(cfgHosts))
	mapping := make(map[string]host.Runtime, len(cfgHosts))
	for _, dsn := range cfgHosts {
		fmt.Printf("读取执行主机: %s\n", dsn)
		u, e := url.Parse(dsn)
		if e != nil {
			return e
		}

		h := host.NewFromDSN(u)
		hostname := h.Hostname(ctx)
		if !host.IsValidHostname(hostname) {
			return fmt.Errorf("hostname invalid: %s", hostname)
		}

		hosts = append(hosts, h)
		mapping[hostname] = h
	}

	// 传输SFTP数据
	//wg := new(sync.WaitGroup)
	//sftpErrC := make(chan error, len(cfgSftp))
	//for hostname, files := range cfgSftp {
	//	if h, ok := mapping[hostname]; ok {
	//		fmt.Printf("传输SFTP数据[%s]: %v\n", hostname, files)
	//		wg.Add(1)
	//		go func() {
	//			defer wg.Done()
	//			if err := <-exec.sftpToRemote(ctx, h, files...); err != nil {
	//				sftpErrC <- err
	//			}
	//		}()
	//	}
	//}

	//wg.Wait()
	//if err := <-exec.handleErrorChannel(sftpErrC); err != nil {
	//	return err
	//}

	// 读取执行脚本
	scripts := make(map[string][]scriptInfo, len(cfgSpecial))
	for _, h := range hosts {
		hostname := h.Hostname(ctx)
		for _, file := range cfgScripts {
			fmt.Printf("读取执行脚本[%s]: %s\n", hostname, file)
			f, e := os.Open(file)
			if e != nil {
				return e
			}
			tpl, e := io.ReadAll(f)
			if e != nil {
				return e
			}

			script := scriptInfo{file: file, tmpl: string(tpl)}
			scripts[hostname] = append(scripts[hostname], script)
		}
	}

	// 读取特殊脚本
	for hostname, files := range cfgSpecial {
		for _, file := range files {
			fmt.Printf("读取特殊脚本[%s]: %s\n", hostname, file)
			f, e := os.Open(file)
			if e != nil {
				return e
			}
			tpl, e := io.ReadAll(f)
			if e != nil {
				return e
			}

			script := scriptInfo{file: file, tmpl: string(tpl)}
			scripts[hostname] = append(scripts[hostname], script)
		}
	}

	// 设置模板数据
	metadata := exec.metadata.SetConfigs(ctx, exec.config)
	metadata = exec.metadata.SetAllHosts(ctx, hosts...)
	metadata_, _ := json.Marshal(metadata)
	fmt.Printf("设置脚本数据: %s\n", string(metadata_))

	// 开始构建脚本
	wg := new(sync.WaitGroup)
	scriptErrC := make(chan error, len(scripts)*2)
	for hostname, files := range scripts {
		if h, ok := mapping[hostname]; ok {
			wg.Add(1)
			go func() {
				defer wg.Done()
				metadata = metadata.SetThisHost(ctx, h)
				if err := <-exec.building(ctx, h, metadata, files...); err != nil {
					scriptErrC <- err
					return
				}
				if err := <-exec.running(ctx, h, files...); err != nil {
					scriptErrC <- err
					return
				}
			}()
		}
	}

	wg.Wait()
	err := <-exec.handleErrorChannel(scriptErrC)

	return err
}

func (exec *Executor) building(ctx context.Context, h host.Runtime, metadata Metadata, files ...scriptInfo) <-chan error {
	errC := make(chan error, len(files))

	buildFn := func(ctx context.Context, errC chan error, h host.Runtime, metadata Metadata, file scriptInfo) {
		exec.runtime.Builder(ctx, "go-tmpl").
			Filename(file.file).
			Template(file.tmpl).
			Metadata(metadata).
			Building(ctx, h, func(ctx context.Context, err error) {
				errC <- err
			})
	}

	if exec.parallel {
		wg := new(sync.WaitGroup)
		for _, file := range files {
			wg.Add(1)
			go func(file scriptInfo) {
				defer wg.Done()
				buildFn(ctx, errC, h, metadata, file)
			}(file)
		}
		wg.Wait()
	} else {
		for _, file := range files {
			buildFn(ctx, errC, h, metadata, file)
		}
	}

	return exec.handleErrorChannel(errC)
}

func (exec *Executor) running(ctx context.Context, h host.Runtime, files ...scriptInfo) <-chan error {
	errC := make(chan error, len(files))

	//if exec.parallel {
	//	wg := new(sync.WaitGroup)
	//	for _, file := range files {
	//		wg.Add(1)
	//		go func(file scriptInfo) {
	//			defer wg.Done()
	//			errC <- exec.runtime.Runner(ctx, "ssh-pty").Run(ctx, file.file, h)
	//		}(file)
	//	}
	//	wg.Wait()
	//} else {
	for _, file := range files {
		errC <- exec.runtime.Runner(ctx, "ssh-pty").Run(ctx, file.file, h)
	}
	//}

	return exec.handleErrorChannel(errC)
}

func (exec *Executor) sftpToRemote(ctx context.Context, h host.Runtime, files ...string) <-chan error {
	errC := make(chan error, len(files))
	sftpFn := func(ctx context.Context, errC chan error, h host.Runtime, file string) {
		workdir := h.Workdir(ctx)
		errC <- h.PTY(ctx, "xterm").Sftp(ctx).CopyFile(ctx, file, workdir)
	}

	if exec.parallel {
		wg := new(sync.WaitGroup)
		for _, file := range files {
			wg.Add(1)
			go func(file string) {
				defer wg.Done()
				sftpFn(ctx, errC, h, file)
			}(file)
		}
		wg.Wait()
	} else {
		for _, file := range files {
			sftpFn(ctx, errC, h, file)
		}
	}

	return exec.handleErrorChannel(errC)

}

func (exec *Executor) handleErrorChannel(errC chan error) <-chan error {
	close(errC)
	errs := make([]string, 0, len(errC))
	for e := range errC {
		if e != nil {
			errs = append(errs, e.Error())
		}
	}

	retC := make(chan error, 1)
	defer close(retC)
	if len(errs) == 0 {
		retC <- nil
	} else {
		retC <- fmt.Errorf("%s", strings.Join(errs, "\n"))
	}

	return retC
}
