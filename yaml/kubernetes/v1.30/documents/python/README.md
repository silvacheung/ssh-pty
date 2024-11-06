# 安装[pyenv](https://github.com/pyenv/pyenv), [installer](https://github.com/pyenv/pyenv-installer)

## 执行安装
```shell
# 安装依赖项
# https://github.com/pyenv/pyenv/wiki#suggested-build-environment
sudo apt update
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev curl git libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# https://github.com/pyenv/pyenv
# https://github.com/pyenv/pyenv-installer
curl https://pyenv.run | bash

# ~/.bashrc
# Bash 警告：有些系统将BASH_ENV变量配置为指向。在这样的.bashrc系统上，
# 您几乎肯定应该将 eval "$(pyenv init -)"行放入.bash_profile，而不是.bashrc。
# 否则，您可能会观察到奇怪的行为，例如pyenv陷入无限循环。有关详细信息，请参阅#264。
if [ -f ~/.bashrc ]; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
  echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi

# ~/.profile
if [ -f ~/.profile ]; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile
  echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile
  echo 'eval "$(pyenv init -)"' >> ~/.profile
fi

# ~/.bash_profile
if [ -f ~/.bash_profile ]; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
  echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
  echo 'eval "$(pyenv init -)"' >> ~/.bash_profile
fi

# -f ~/.zshrc
if [ -f ~/.zshrc ]; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
  echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
  echo 'eval "$(pyenv init -)"' >> ~/.zshrc
fi

# 重启 shell
exec "$SHELL"
```

## 使用
```shell
# 安装其他 Python 版本
# 可以预先下载Python到$PYENV_ROOT/cache,可以加快安装
# mkdir -p $PYENV_ROOT/cache
# curl -L -o $PYENV_ROOT/cache/Python-3.10.4.tar.xz https://mirrors.aliyun.com/python-release/source/Python-3.10.4.tar.xz
pyenv install 3.10.4

# 为实现最高性能而构建
env PYTHON_CONFIGURE_OPTS='--enable-optimizations --with-lto' PYTHON_CFLAGS='-march=native -mtune=native' pyenv install --verbose 3.6.0

# 卸载其他 Python 版本
pyenv uninstall 3.10.4

# 所有可用版本的列表
pyenv install -l

# 切换到指定版本
pyenv global 3.10

# 在 Python 版本之间切换（使用“ system”作为版本名称会将选择重置为系统提供的 Python）
# -- 仅为当前 shell 会话选择
pyenv shell <version>
# -- 当您位于当前目录（或其子目录）时自动选择
pyenv local <version>
# -- 为您的用户帐户进行全局选择
pyenv global <version>

```

## 更新
```shell
pyenv update
```

## 卸载
```shell
# https://github.com/pyenv/pyenv?tab=readme-ov-file#uninstalling-pyenv
# https://github.com/pyenv/pyenv-installer?tab=readme-ov-file#uninstall
```

# 安装新的Python与系统Python共存（需要使用时需要指定版本，如python3.xx，而不是python3，因为python3还是系统python，不能动）
```shell
# 安装依赖
apt update
# apt install -y curl build-essential libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev libffi-dev
apt install -y curl git build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# 指定版本，这里使用系统版本
# VERSION is python version eg: 3.xx.xx
VERSION=$(python3 -V | awk '{print$2}')

# 下载指定版本包
# curl -LO https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz
curl -LO https://mirrors.aliyun.com/python-release/source/Python-${VERSION}.tgz

# 解压并编译安装
tar -xvf Python-${VERSION}.tgz
cd Python-${VERSION}
./configure --enable-optimizations --with-lto --prefix=/usr/local
make && make altinstall # 使用altinstall而不是install以避免覆盖系统默认的python版本

# 创建软链使用指定版本（这里注意不要覆盖了系统本身的python3链）
# cd ..
# update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.8 100
# update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.8 100
# update-alternatives --config python3
cd ..
if [ ! -f /usr/bin/python${VERSION%.*} ]; then
  update-alternatives --install /usr/bin/python${VERSION%.*} python${VERSION%.*} /usr/local/bin/python${VERSION%.*} 999
fi
if [ ! -f /usr/bin/pip${VERSION%.*} ]; then
  update-alternatives --install /usr/bin/pip${VERSION%.*} pip${VERSION%.*} /usr/local/bin/pip${VERSION%.*} 999
fi

# 更新环境变量，让使用相同版本的python时优先走非系统python
cat > /etc/profile.d/Z999_set_usr_local_path.sh <<EOF
export PATH="/usr/local/bin:$PATH"
EOF
chmod +x /etc/profile.d/Z999_set_usr_local_path.sh
source /etc/profile

# 设置pip源
pip${VERSION%.*} config set global.index-url https://mirrors.aliyun.com/pypi/simple --trusted-host mirrors.aliyun.com
```