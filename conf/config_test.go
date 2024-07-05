package conf

import (
	"bytes"
	"fmt"
	"io"
	"net/url"
	"os"
	"strings"
	"testing"
	"text/template"
)

func TestConfig(t *testing.T) {
	config, err := New("")
	if err != nil {
		t.Fatal(err)
	}

	tmplFile, err := os.Open("")
	if err != nil {
		t.Fatal(err)
	}
	defer tmplFile.Close()

	tmpl, err := io.ReadAll(tmplFile)
	if err != nil {
		t.Fatal(err)
	}

	tpl := template.New("test").Funcs(map[string]any{
		"get":        config.Get,
		"key":        config.IsSet,
		"url":        url.Parse,
		"split":      strings.Split,
		"trim":       strings.Trim,
		"trimSpace":  strings.TrimSpace,
		"trimPrefix": strings.TrimPrefix,
		"trimSuffix": strings.TrimSuffix,
		"trimLeft":   strings.TrimLeft,
		"trimRight":  strings.TrimRight,
		"hasPrefix":  strings.HasPrefix,
		"hasSuffix":  strings.HasSuffix,
		"contains":   strings.Contains,
		"replace":    strings.Replace,
	})

	tpl, err = tpl.Parse(string(tmpl))
	if err != nil {
		t.Fatal(err)
	}

	buf := new(bytes.Buffer)
	err = tpl.Execute(buf, config.AllSettings())
	if err != nil {
		t.Fatal(err)
	}

	fmt.Print(buf.String())
}
