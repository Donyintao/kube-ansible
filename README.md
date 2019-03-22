# Ansible kubernetes install

## 部署前提和注意事项

### 下载kubernetes二进制文件

注意: `kubernetes`所有二进制文件均提供下载 https://pan.baidu.com/s/1LWI6rL2Pgo27nohhvA5LwA 提取码: wn4b 

说明: 将`kube-master`和`kube-node`下载好的二进制文件放到指定的文件目录

```sh
# cp -r kube-master-v1.13.4.tar.gz roles/kube-master/files/kubernetes-v1.13.4.tar.gz
# cp -r kube-node-v1.13.4.tar.gz roles/kube-node/files/kubernetes-v1.13.4.tar.gz
```

### 配置集群主机信息

说明: 根据实际情况填写相关主机信息

```sh
# vim inventory/hosts
[etcd-nodes]
172.16.0.101    ETCD_NAME=etcd-node1
172.16.0.102    ETCD_NAME=etcd-node2
172.16.0.103    ETCD_NAME=etcd-node3

[kube-master]
172.16.0.101
172.16.0.102
172.16.0.103

[kube-node]
172.16.0.101
172.16.0.102
172.16.0.103

[haproxy]
172.16.0.101  STATE=MASTER PRIORITY=200
172.16.0.102  STATE=BACKUP PRIORITY=150
```

### 配置集群环境变量

说明: 根据实际情况填写相关环境变量

```sh
# vim inventory/group_vars/all.yaml
## Etcd variable
ETCD_HOME_PATH: '/etc/etcd'
ETCD_CERT_PATH: '{{ ETCD_HOME_PATH }}/ssl'
ETCD_DATA_PATH: '/var/lib/etcd'
ETCD_CLUSTER_ADDRESS: 'https://{{ KUBE_MASTER1_ADDRESS }}:2379,https://{{ KUBE_MASTER2_ADDRESS }}:2379,https://{{ KUBE_MASTER3_ADDRESS }}:2379'
ETCD_CLUSTER_LIST: 'etcd-node1=https://{{ KUBE_MASTER1_ADDRESS }}:2380,etcd-node2=https://{{ KUBE_MASTER2_ADDRESS }}:2380,etcd-node3=https://{{ KUBE_MASTER3_ADDRESS }}:2380'

## Flannel variable
#FLANNEL_ETCD_NETWORK: '/flannel/network'
#FLANNEL_CERT_PATH: '/etc/flannel/ssl'
#FLANNEL_CA_FILE: '{{ FLANNEL_CERT_PATH }}/ca.pem'
#FLANNEL_CERT_FILE: '{{ FLANNEL_CERT_PATH }}/flanneld.pem'
#FLANNEL_kEY_FILE: '{{ FLANNEL_CERT_PATH }}/flanneld-key.pem'
#FLANNEL_OPTIONS: '-iface=eth0 -ip-masq -etcd-cafile={{ FLANNEL_CA_FILE }} -etcd-certfile={{ FLANNEL_CERT_FILE }} -etcd-keyfile={{ FLANNEL_kEY_FILE }}'

## Docker variable
DOCKER_DATA_PATH: '/data/docker'
DOCKER_REGSTRY_MIRRORS: 'http://d7eabb7d.m.daocloud.io'

## Kubernetes variable
KUBE_CERTS_PATH: '/tmp/sslTmp'
KUBE_MASTER1_ADDRESS: '172.16.0.101'
KUBE_MASTER2_ADDRESS: '172.16.0.102'
KUBE_MASTER3_ADDRESS: '172.16.0.103'
KUBE_HOME_PARENT: '/usr/local'
KUBE_HOME_PATH: '{{ KUBE_HOME_PARENT }}/kubernetes'
KUBE_LOGS_PATH: '/data/logs/kubernetes'
KUBE_VERSION: 'v1.13.4'
KUBE_MASTER_VIP: '172.16.0.253'
KUBE_INGRESS_VIP: '172.16.0.252'
KUBE_CLUSTER_CIDR: '10.240.0.0/16'
KUBE_SERVICE_CIDR: '10.241.0.0/16'
KUBE_SERVICE_DNS_IP: '10.241.0.254'
KUBE_SERVICE_SVC_IP: '10.241.0.1'
KUBE_PORT_RANGE: '30000-60000'
KUBE_KUBELET_DIR: '/data/kubelet'
KUBE_CLUSTER_NAME: 'linux-testing'
KUBE_POD_IMAGES: 'k8s.gcr.io/pause:3.1'

## Haproxy variable
HAPROXY_MASTER_ADDRESS: '172.16.0.104'
HAPROXY_BACKUP_ADDRESS: '172.16.0.105'
```

## ansible-playbook服务部署

#### Create Certs

`# ansible-playbook playbooks/certs_install.yaml -i inventory/hosts`

#### Etcd install

`# ansible-playbook playbooks/etcd_install.yaml -i inventory/hosts`

#### Docker install

`# ansible-playbook playbooks/docker_install.yaml -i inventory/hosts`

#### Kubernetes master install

`# ansible-playbook playbooks/kube-master_install.yaml -i inventory/hosts`

#### Kubernetes nodes install

`# ansible-playbook playbooks/kube-node_install.yaml -i inventory/hosts`

#### 验证集群环境
```sh
# kubectl get nodes -o wide
NAME        STATUS   ROLES    AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
k8s-node1   Ready    <none>   23h     v1.13.4   172.16.0.101   <none>        CentOS Linux 7 (Core)   4.4.166-1.el7.elrepo.x86_64   docker://18.6.3
k8s-node2   Ready    <none>   7h10m   v1.13.4   172.16.0.102   <none>        CentOS Linux 7 (Core)   4.4.166-1.el7.elrepo.x86_64   docker://18.6.3
k8s-node3   Ready    <none>   23h     v1.13.4   172.16.0.103   <none>        CentOS Linux 7 (Core)   4.4.166-1.el7.elrepo.x86_64   docker://18.6.3
```
