package main

import (
	"context"
	"flag"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/script"
	"log"
)

var config string

func init() {
	flag.StringVar(&config, "config", "D:\\workspace\\ssh-pty\\yamls\\kubernetes\\v1.30\\k8s-install.yaml", "指定一个脚本执行配置文件")
	flag.Usage = func() { flag.PrintDefaults() }
	flag.Parse()
}

func main() {
	ctx := context.Background()
	cfg, err := conf.New(config)
	if err != nil {
		log.Fatalln(err)
	}

	err = script.
		NewExecutor().
		SetRuntime(script.NewFactory()).
		SetParallel(true).
		SetConfig(cfg).
		Executing(ctx)

	if err != nil {
		log.Fatalln(err)
	}
}
