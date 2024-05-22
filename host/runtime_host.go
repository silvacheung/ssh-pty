package host

import (
	"context"
	"fmt"
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
	workdir    string
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

func WithWorkdir(workdir string) Option {
	workdir = strings.TrimSuffix(workdir, "/")
	return func(opt *options) {
		opt.workdir = workdir
	}
}

type Host struct {
	*options
}

func New(opts ...Option) Runtime {
	h := &Host{options: &options{
		workdir: "/var/ssh-pty/workdir",
	}}
	for _, opt := range opts {
		opt(h.options)
	}
	return h
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

func (h *Host) Workdir(context.Context) string {
	return h.workdir
}

func (h *Host) String(ctx context.Context) string {
	return fmt.Sprintf("%s:***@%s:%s/%s?hostname=%s&privateKey=***",
		h.Username(ctx), h.Address(ctx), h.Port(ctx), strings.TrimPrefix(h.Workdir(ctx), "/"), h.Hostname(ctx))
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
