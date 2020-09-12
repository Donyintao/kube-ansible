## Ansible kubernetes install

### 部署前提和注意事项

脚本里有判断相关文件下载，因为外网原因下载成功率不高，建议提前采用手动方式进行下载。

```sh
$ cd /tmp
# 下载kubernetes server压缩包, 说明: 压缩包版本建议与"${KUBE_APP_VERSION}"保持一致
$ wget https://storage.googleapis.com/kubernetes-release/release/v1.18.8/kubernetes-server-linux-amd64.tar.gz
$ tar fx kubernetes-server-linux-amd64.tar.gz
# 下载cni压缩包
$ wget https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
$ mkdir -p /tmp/cni
$ tar fx cni-plugins-linux-amd64-v0.8.7.tgz -C /tmp/cni
```

### 下载 ansible 一键生成脚本

```bash
$ wget https://raw.githubusercontent.com/Donyintao/kube-ansible/master/kubernetes.v1.18.sh
# 注意: 记得根据实际情况修改配置参数
$ sh -x kubernetes.v1.18.sh
```

### Kubernetes 集群安装
```bash
$ cd /tmp/playbooks
$ ansible-playbook etcd.yaml docker.yaml kube-master.yaml kube-node.yaml -i inventory/hosts
```

### Kubernetes 集群验证

说明: ansible 一键生成脚本中默认没有开启8080端口，建议手动生成`config`文件后，执行`kubectl get node`验证集群状态


