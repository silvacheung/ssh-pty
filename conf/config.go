package conf

import (
	"bytes"
	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
	"io"
	"os"
)

type Config struct {
	*viper.Viper
	Metadata map[string]any
}

func New(file string) (config *Config, err error) {
	config = &Config{
		Viper:    viper.New(),
		Metadata: make(map[string]any),
	}

	f, e := os.Open(file)
	if e != nil {
		return nil, e
	}

	bs, e := io.ReadAll(f)
	if e != nil {
		return nil, e
	}

	if e = yaml.Unmarshal(bs, &config.Metadata); e != nil {
		return nil, e
	}

	config.SetConfigType("yaml")
	return config, config.ReadConfig(bytes.NewReader(bs))
}
