# From [ctrox/csi-s3](https://github.com/ctrox/csi-s3)

## 修改了[csi-s3-attacher.yaml](csi-s3-attacher.yaml)
### 如果按照官网的原始文件部署，会有权限问题，故作了修改（注释内容部分）

## 添加了[csi-s3-pvc-template.yaml](csi-s3-pvc-template.yaml)
### 这个模板可以使用AWS的S3或者支持S3协议的存储，需要根据业务灵活修改`csi-s3-pvc-template.yaml`配置

## 部署步骤
```shell
kubectl apply -f csi-s3.yaml
kubectl apply -f csi-s3-attacher.yaml
kubectl apply -f csi-s3-provisioner.yaml
kubectl apply -f csi-s3-pvc-template.yaml
```