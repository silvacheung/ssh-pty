package main

import (
	"context"
	"flag"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/script"
	"log"
)

var configYaml string

func init() {
	flag.StringVar(&configYaml, "config", "D:\\workspace\\ssh-pty\\yamls\\kubernetes\\v1.30\\worker-node\\worker-node.yaml", "指定一个脚本执行配置文件")
	flag.Usage = func() { flag.PrintDefaults() }
	flag.Parse()
}

func main() {
	ctx := context.Background()
	config, err := conf.New(configYaml)
	if err != nil {
		log.Fatalln(err)
	}

	err = script.
		NewExecutor(config, script.NewFactory()).
		Executing(ctx)

	if err != nil {
		log.Fatalln(err)
	}
}
