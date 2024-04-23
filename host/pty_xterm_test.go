package host

import (
	"context"
	"io"
	"strings"
	"testing"
)

func TestXterm(t *testing.T) {
	ctx := context.Background()

	h := New(
		WithAddress("127.0.0.1"),
		WithPort("22"),
		WithUsername("test"),
		WithPassword("123456"),
	)

	err := h.PTY(ctx, "xterm").Shell(ctx).
		Stdin(func(ctx context.Context, stdin io.Writer) {
			_, _ = stdin.Write([]byte("echo '123'"))
		}).
		Stdout(func(ctx context.Context, stdin io.Writer, buf []byte) {
			line := string(buf)
			// 输入密码
			if (strings.HasPrefix(line, "[sudo] password for ") ||
				strings.HasPrefix(line, "Password")) &&
				strings.HasSuffix(line, ": ") {
				_, _ = stdin.Write([]byte("echo '123456'"))
			}
			// 完整的行
			if buf[len(buf)-1] == '\n' {
				t.Logf("%s", line)
			}
		}).
		Exited(func(ctx context.Context, code int, out []byte) error {
			t.Logf("output(%d):%s", code, string(out))
			return nil
		})

	t.Log(err)
}
