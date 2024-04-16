package host

import (
	"context"
)

type Runtime interface {
	// Hostname 获取本主机名称
	Hostname(context.Context) string
	// Address 获取本主机访问地址
	Address(context.Context) string
	// Internal 获取主机内网地址
	Internal(context.Context) string
	// Port 获取本主机访问端口
	Port(context.Context) string
	// Username 获取本主机SSH用户名
	Username(context.Context) string
	// Password 获取本主机SSH密码
	Password(context.Context) string
	// PrivateKEY 获取本主机SSH私钥
	PrivateKEY(context.Context) string
	// NetIF 获取本主机网络接口
	NetIF(context.Context) string
	// Workdir 返回工作目录
	Workdir(context.Context) string
	// Values 获取所有的Values
	Values(context.Context) map[string]string
	// PTY 获取本主机的伪终端
	PTY(context.Context, string) Pty
}
