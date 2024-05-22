package conf

import (
	"bytes"
	"testing"
	"text/template"
)

func TestConfig(t *testing.T) {
	config, err := New("")
	if err != nil {
		t.Fatal(err)
	}

	tpl := template.New("test").Funcs(map[string]any{
		"get": config.Get,
		"has": config.IsSet,
		"not": func(key string) bool { return !config.IsSet(key) },
	})

	tpl, err = tpl.Parse(``)
	if err != nil {
		t.Fatal(err)
	}

	buf := new(bytes.Buffer)
	err = tpl.Execute(buf, config.AllSettings())
	if err != nil {
		t.Fatal(err)
	}

	t.Logf(buf.String())
}
