package main

import (
	"context"
	"flag"
	"github.com/silvacheung/ssh-pty/conf"
	"github.com/silvacheung/ssh-pty/script"
	"log"
)

var Args struct {
	YamlFile string
}

func init() {
	flag.StringVar(&Args.YamlFile, "config", "D:\\workspace\\ssh-pty\\yamls\\kubernetes\\v1.30\\load-balancer\\load-balancer.yaml", "指定一个脚本执行配置文件")
	flag.Usage = func() { flag.PrintDefaults() }
	flag.Parse()
}

func main() {
	ctx := context.Background()
	config, err := conf.New(Args.YamlFile)
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
