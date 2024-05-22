package script

import (
	"context"
	"fmt"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/host"
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

func (exec *Executor) Executing(ctx context.Context) (err error) {
	setHosts := exec.config.IsSet("hosts")
	setScript := exec.config.IsSet("script")
	setSftp := exec.config.IsSet("sftp")
	if !setHosts || (!setScript && !setSftp) {
		return fmt.Errorf("配置文件错误: 未设置执行主机、执行脚本/传输文件！")
	}

	// 读取执行主机
	hosts := make([]host.Runtime, 0, 100)
	for i := 0; ; i++ {
		key := fmt.Sprintf("hosts.%d", i)
		if !exec.config.InConfig(key) {
			break
		}

		h := host.New(
			host.WithHostname(exec.config.GetString(key+".hostname")),
			host.WithAddress(exec.config.GetString(key+".address")),
			host.WithInternal(exec.config.GetString(key+".internal")),
			host.WithPort(exec.config.GetString(key+".port")),
			host.WithUsername(exec.config.GetString(key+".username")),
			host.WithPassword(exec.config.GetString(key+".password")),
			host.WithPrivateKEY(exec.config.GetString(key+".privateKey")),
			host.WithWorkdir(exec.config.GetString(key+".workdir")),
		)

		fmt.Printf("读取执行主机:%s\n", h.String(ctx))
		if !host.IsValidHostname(h.Hostname(ctx)) {
			return fmt.Errorf("hostname invalid: %s", h.String(ctx))
		}

		hosts = append(hosts, h)
	}

	// 读取执行脚本
	scripts := exec.config.GetStringSlice("script")
	scriptFiles := make(map[string][]string, len(scripts))
	for _, h := range hosts {
		hostname := h.Hostname(ctx)
		for _, file := range scripts {
			fmt.Printf("读取执行脚本[%s]:%s\n", hostname, file)
			scriptFiles[hostname] = append(scriptFiles[hostname], file)
		}
	}

	// 执行单元
	sftp := exec.config.GetStringMapStringSlice("sftp")
	units := make(map[string]*Unit, len(hosts))
	for i := range hosts {
		key := fmt.Sprintf("hosts.%d", i)
		config := exec.config.Clone()
		config.Set("host", exec.config.Get(key))
		this := hosts[i]
		hostname := this.Hostname(ctx)
		units[hostname] = &Unit{
			wg:         new(sync.WaitGroup),
			config:     config,
			runtime:    exec.runtime,
			hosts:      hosts,
			this:       this,
			sftpFiles:  sftp[hostname],
			shellFiles: scriptFiles[hostname],
			waits:      make([]*Unit, 0, 2),
		}
	}

	// 依赖执行
	awaits := exec.config.GetStringMapStringSlice("await")
	errC := make(chan error, len(units))
	for hostname := range units {
		unit := units[hostname]
		awaitHosts := awaits[hostname]
		for _, awaitHostname := range awaitHosts {
			if awaitUnit := units[awaitHostname]; awaitUnit != nil {
				unit.waits = append(unit.waits, awaitUnit)
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
	for err = range errC {
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
	waits      []*Unit
	err        error
}

func (u *Unit) ExecGo(ctx context.Context, errC chan<- error) {
	u.wg.Add(1)
	go func() {
		defer u.wg.Done()
		u.sftp(ctx)
		u.building(ctx)
		u.waitingUnits(ctx)
		u.executing(ctx)
		errC <- u.err
	}()
}

func (u *Unit) Await() {
	u.wg.Wait()
}

func (u *Unit) sftp(ctx context.Context) {
	if u.err != nil || len(u.sftpFiles) == 0 {
		return
	}
	workdir := u.this.Workdir(ctx)
	sftp := u.this.PTY(ctx, "xterm").Sftp(ctx)
	for _, f := range u.sftpFiles {
		if u.err = sftp.Copy(ctx, f, workdir); u.err != nil {
			break
		}
	}
}

func (u *Unit) building(ctx context.Context) {
	if u.err != nil || len(u.shellFiles) == 0 {
		return
	}

	errC := make(chan error, len(u.shellFiles))
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
			u.runtime.Builder(ctx, "go-template").
				File(file).Config(u.config).
				Build(ctx, u.this, func(ctx context.Context, err error) {
					errC <- err
				})
		}(file)
	}

	wg.Wait()
	close(parallelC)
	u.err = <-u.handleErrorC(errC)
}

func (u *Unit) executing(ctx context.Context) {
	if u.err != nil || len(u.shellFiles) == 0 {
		return
	}

	for _, file := range u.shellFiles {
		if u.err = u.runtime.Runner(ctx, "ssh-pty").Run(ctx, u.this, file); u.err != nil {
			break
		}
	}
}

func (u *Unit) waitingUnits(ctx context.Context) {
	if u.err != nil || len(u.waits) == 0 {
		return
	}

	for _, unit := range u.waits {
		if u.err = ctx.Err(); u.err != nil {
			break
		}
		hostname := u.this.Hostname(ctx)
		waitHostname := unit.this.Hostname(ctx)
		fmt.Printf("等待依赖执行结束[%s]:%s\n", hostname, waitHostname)
		if unit.Await(); unit.err != nil {
			u.err = fmt.Errorf("依赖执行错误，取消执行[%s]:%s", hostname, waitHostname)
			break
		}
	}
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
