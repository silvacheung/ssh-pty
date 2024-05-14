package host

import (
	"context"
	"log"
	"net/url"
	"regexp"
	"strings"
)

type options struct {
	hostname   string
	address    string
	internal   string
	port       string
	username   string
	password   string
	privateKEY string
	netIF      string
	workdir    string
	values     map[string]string
}

type Option func(opt *options)

func WithHostname(hostname string) Option {
	return func(opt *options) {
		opt.hostname = hostname
	}
}

func WithAddress(address string) Option {
	return func(opt *options) {
		opt.address = address
	}
}

func WithInternal(address string) Option {
	return func(opt *options) {
		opt.internal = address
	}
}

func WithPort(port string) Option {
	return func(opt *options) {
		opt.port = port
	}
}

func WithUsername(username string) Option {
	return func(opt *options) {
		opt.username = username
	}
}

func WithPassword(password string) Option {
	return func(opt *options) {
		opt.password = password
	}
}

func WithPrivateKEY(key string) Option {
	return func(opt *options) {
		opt.privateKEY = key
	}
}

func WithNetIF(netIF string) Option {
	return func(opt *options) {
		opt.netIF = netIF
	}
}

func WithWorkdir(workdir string) Option {
	return func(opt *options) {
		opt.workdir = workdir
	}
}

func WithValues(values map[string]string) Option {
	return func(opt *options) {
		opt.values = values
	}
}

type Host struct {
	*options
}

func New(opts ...Option) Runtime {
	h := &Host{options: &options{}}
	for _, opt := range opts {
		opt(h.options)
	}
	return h
}

func NewFromDSN(URL *url.URL) Runtime {
	query := URL.Query()
	if query == nil {
		log.Fatalln("hosts dsn format invalid:", URL.String())
	}

	netIF := URL.Scheme
	hostname := query.Get("hostname")
	internal := query.Get("internal")
	workdir := query.Get("workdir")
	privateKEY := query.Get("private-key")
	address := URL.Hostname()
	port := URL.Port()
	username := ""
	password := ""
	if URL.User != nil {
		username = URL.User.Username()
		password, _ = URL.User.Password()
	}

	values := make(map[string]string, len(query))
	for k, v := range query {
		if k != "" && len(v) > 0 && v[0] != "" {
			values[k] = v[0]
		}
	}

	delete(values, "hostname")
	delete(values, "internal")
	delete(values, "workdir")
	delete(values, "private-key")

	if workdir == "" {
		workdir = "/var/ssh-pty/workdir"
	}

	return New(
		WithHostname(hostname),
		WithInternal(internal),
		WithAddress(address),
		WithPort(port),
		WithUsername(username),
		WithPassword(password),
		WithNetIF(netIF),
		WithWorkdir(strings.TrimSuffix(workdir, "/")),
		WithPrivateKEY(privateKEY),
		WithValues(values))
}

func (h *Host) Hostname(context.Context) string {
	return h.hostname
}

func (h *Host) Address(context.Context) string {
	return h.address
}

func (h *Host) Internal(context.Context) string {
	return h.internal
}

func (h *Host) Port(context.Context) string {
	return h.port
}

func (h *Host) Username(context.Context) string {
	return h.username
}

func (h *Host) Password(context.Context) string {
	return h.password
}

func (h *Host) PrivateKEY(context.Context) string {
	return h.privateKEY
}

func (h *Host) NetIF(context.Context) string {
	return h.netIF
}

func (h *Host) Workdir(context.Context) string {
	return h.workdir
}

func (h *Host) Values(context.Context) map[string]string {
	return h.values
}

func (h *Host) PTY(ctx context.Context, name string) Pty {
	fn := GetPTY(name)
	if fn != nil {
		return fn(ctx, h)
	}
	return nil
}

var hostnameRegexp, _ = regexp.Compile(`^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-.]{0,61}[a-zA-Z0-9])$`)

func IsValidHostname(hostname string) bool {
	return hostnameRegexp.MatchString(hostname)
}
