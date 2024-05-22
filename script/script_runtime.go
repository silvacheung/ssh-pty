package script

import "context"

var builders = make(map[string]func(ctx context.Context) Builder)

func SetBuilder(name string, builder func(ctx context.Context) Builder) {
	builders[name] = builder
}

func GetBuilder(name string) func(ctx context.Context) Builder {
	return builders[name]
}

var runners = make(map[string]func(ctx context.Context) Runner)

func SetRunner(name string, builder func(ctx context.Context) Runner) {
	runners[name] = builder
}

func GetRunner(name string) func(ctx context.Context) Runner {
	return runners[name]
}

func init() {
	SetBuilder("go-template", NewTemplate)
	SetRunner("ssh-pty", NewSSHPty)
}

type Factory struct{}

func NewFactory() Runtime {
	return Factory{}
}

func (Factory) Builder(ctx context.Context, name string) Builder {
	fn := GetBuilder(name)
	if fn != nil {
		return fn(ctx)
	}
	return nil
}

func (Factory) Runner(ctx context.Context, name string) Runner {
	fn := GetRunner(name)
	if fn != nil {
		return fn(ctx)
	}
	return nil
}
