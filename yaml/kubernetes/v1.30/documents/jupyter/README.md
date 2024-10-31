# 安装Jupyter Lab（https://jupyter.org/install）

## 安装
```shell
# 设置pip源
pip3 config set global.index-url https://mirrors.aliyun.com/pypi/simple --trusted-host mirrors.aliyun.com

# 安装JupyterLab
pip3 install jupyterlab==4.3.0
```

## 设置服务
```shell
cat > /etc/systemd/system/jupyter-lab.service <<EOF
[Unit]
Description=jupyter-lab
Documentation=

[Service]
Type=simple
ExecStart=/usr/local/bin/jupyter lab --ip=0.0.0.0 --allow-root
Restart=always
RestartSec=3
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start jupyter-lab
systemctl enable jupyter-lab --now
systemctl is-active jupyter-lab
systemctl is-enabled jupyter-lab
```