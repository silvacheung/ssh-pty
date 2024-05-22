package conf

import (
	"bytes"
	"github.com/spf13/viper"
	"io"
	"os"
)

type Config struct {
	*viper.Viper
	raw []byte
}

func New(file string) (config *Config, err error) {
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}

	bs, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}

	config = &Config{Viper: viper.New(), raw: bs}
	config.SetConfigType("yaml")
	return config, config.ReadConfig(bytes.NewReader(config.raw))
}

func (c *Config) Clone() *Config {
	clone := &Config{Viper: viper.New(), raw: c.raw}
	clone.SetConfigType("yaml")
	_ = clone.ReadConfig(bytes.NewReader(clone.raw))
	return clone
}
