package script

import (
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
	"io"
	"net/url"
	"os"
	"strings"
	"sync"
)

type Executor struct {
	runtime Runtime
	config  *conf.Config
}

func NewExecutor(config *conf.Config, runtime Runtime) *Executor {
	return &Executor{config: config, runtime: runtime}
}

func (exec *Executor) Executing(ctx context.Context) error {
	// 配置文件数据
	cfgHosts := exec.config.GetStringSlice("hosts")
	cfgScripts := exec.config.GetStringSlice("scripts")
	cfgSpecial := exec.config.GetStringMapStringSlice("special")
	cfgSftp := exec.config.GetStringMapStringSlice("sftp")
	cfgAwaits := exec.config.GetStringMapStringSlice("awaits")

	// 读取执行主机
	hosts := make([]host.Runtime, 0, len(cfgHosts))
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
	}

	// 读取执行脚本
	scriptFiles := make(map[string][]string, len(cfgScripts)+len(cfgSpecial))
	scriptTemps := make(map[string]map[string]string, len(cfgScripts)+len(cfgSpecial))
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
			scriptFiles[hostname] = append(scriptFiles[hostname], file)

			templates, ok := scriptTemps[hostname]
			if !ok {
				templates = make(map[string]string, len(cfgScripts))
			}
			templates[file] = string(tpl)
			scriptTemps[hostname] = templates
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
			scriptFiles[hostname] = append(scriptFiles[hostname], file)

			templates, ok := scriptTemps[hostname]
			if !ok {
				templates = make(map[string]string, len(cfgScripts))
			}
			templates[file] = string(tpl)
			scriptTemps[hostname] = templates
		}
	}

	// 执行单元
	units := make(map[string]*Unit, len(hosts))
	for i := range hosts {
		this := hosts[i]
		hostname := this.Hostname(ctx)
		units[hostname] = &Unit{
			wg:         new(sync.WaitGroup),
			config:     exec.config,
			runtime:    exec.runtime,
			hosts:      hosts,
			this:       this,
			sftpFiles:  cfgSftp[hostname],
			shellFiles: scriptFiles[hostname],
			shellTemps: scriptTemps[hostname],
			waits:      make([]*Unit, 0, 2),
		}
	}

	// 依赖执行
	errC := make(chan error, len(units))
	for hostname := range units {
		unit := units[hostname]
		awaits := cfgAwaits[hostname]
		for _, awaitHostname := range awaits {
			if await := units[awaitHostname]; await != nil {
				unit.waits = append(unit.waits, await)
			}
		}
		unit.ExecGo(ctx, errC)
	}

	// 等待所有单元执行完毕
	for _, unit := range units {
		unit.Await()
	}

	// 处理错误
	close(errC)
	for err := range errC {
		if err != nil {
			return err
		}
	}
	return nil
}

type Unit struct {
	wg         *sync.WaitGroup
	config     *conf.Config
	runtime    Runtime
	hosts      []host.Runtime
	this       host.Runtime
	sftpFiles  []string
	shellFiles []string
	shellTemps map[string]string
	waits      []*Unit
}

func (u *Unit) ExecGo(ctx context.Context, errC chan<- error) {
	ech := make(chan error, 4)
	u.wg.Add(1)
	go func() {
		defer u.wg.Done()
		ech <- <-u.sftp(ctx)
		ech <- <-u.building(ctx)
		ech <- <-u.waitingUnits(ctx)
		ech <- <-u.executing(ctx)
		errC <- <-u.handleErrorC(ech)
	}()
}

func (u *Unit) Await() {
	u.wg.Wait()
}

func (u *Unit) sftp(ctx context.Context) <-chan error {
	errC := make(chan error, len(u.sftpFiles))

	workdir := u.this.Workdir(ctx)
	sftp := u.this.PTY(ctx, "xterm").Sftp(ctx)
	for _, f := range u.sftpFiles {
		if err := sftp.Copy(ctx, f, workdir); err != nil {
			errC <- err
		}
	}

	return u.handleErrorC(errC)
}

func (u *Unit) building(ctx context.Context) <-chan error {
	errC := make(chan error, len(u.shellFiles))

	metadata := make(Metadata, 3)
	metadata.SetConfigs(ctx, u.config)
	metadata.SetThisHost(ctx, u.this)
	metadata.SetAllHosts(ctx, u.hosts...)

	parallelC := make(chan struct{}, 5)
	wg := new(sync.WaitGroup)
	for _, file := range u.shellFiles {
		parallelC <- struct{}{}
		wg.Add(1)
		go func(file string) {
			defer func() {
				<-parallelC
				wg.Done()
			}()
			u.runtime.Builder(ctx, "go-tmpl").
				Filename(file).
				Template(u.shellTemps[file]).
				Metadata(metadata).
				Building(ctx, u.this, func(ctx context.Context, err error) {
					errC <- err
				})
		}(file)
	}

	wg.Wait()
	close(parallelC)
	return u.handleErrorC(errC)
}

func (u *Unit) executing(ctx context.Context) <-chan error {
	errC := make(chan error, len(u.shellFiles))
	for _, file := range u.shellFiles {
		if err := u.runtime.Runner(ctx, "ssh-pty").Run(ctx, u.this, file); err != nil {
			errC <- err
		}
	}
	return u.handleErrorC(errC)
}

func (u *Unit) waitingUnits(ctx context.Context) <-chan error {
	errC := make(chan error, len(u.waits))
	if len(u.waits) > 0 {
		for _, unit := range u.waits {
			if err := ctx.Err(); err != nil {
				errC <- err
				break
			}
			fmt.Printf("等待依赖执行结束[%s]: %s\n", u.this.Hostname(ctx), unit.this.Hostname(ctx))
			unit.wg.Wait()
		}
	}
	return u.handleErrorC(errC)
}

func (u *Unit) handleErrorC(errC chan error) <-chan error {
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
