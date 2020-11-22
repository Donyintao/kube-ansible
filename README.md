## Ansible kubernetes install

### 部署前提和注意事项

因为外网速度越来越慢下载而且成功率不高，建议提前采用手动方式进行下载。

```sh
# 下载kubernetes server压缩包
$ cd /tmp
$ wget https://storage.googleapis.com/kubernetes-release/release/v1.18.8/kubernetes-server-linux-amd64.tar.gz
$ tar fx kubernetes-server-linux-amd64.tar.gz
# 下载cni压缩包
$ wget https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
$ mkdir -p cni && tar fx cni-plugins-linux-amd64-v0.8.7.tgz -C cni
```

### ansible一键生成脚本
```sh
$ wget https://raw.githubusercontent.com/Donyintao/kube-ansible/master/kubernetes.v1.18.sh
# 注意: 根据实际环境修改配置参数
$ sh -x kubernetes.v1.18.shß
```

### Kubernetes 集群安装
```sh
$ cd /tmp/ansible-playbook
$ ansible-playbook etcd.yaml docker.yaml kube-master.yaml kube-node.yaml -i inventory/hosts
```


