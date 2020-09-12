## Ansible kubernetes install

### 部署前提和注意事项

github外网速度越来越慢下载且成功率不高，建议提前采用手动方式进行下载。

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
```

根据实际情况修改一键生成脚本的配置参数

```sh
###################################################################################################################################
######################                             记得修改下面的配置参数!!!!!!!                             ######################  
###################################################################################################################################

# 临时目录
TEMP_PATH="/tmp"
# 存储目录
DATA_PATH="/data"
# 安装目录
TOTAL_PATH="/usr/local"
# CFSSL目录
CFSSL_PATH="${TEMP_PATH}/cfssl"
# PLAYBOOK目录
PLAYBOOK_PATH="${TEMP_PATH}/palybooks"

# 证书信息配置
CERT_ST="Beijing"
CERT_L="Beijing"
CERT_O="k8s"
CERT_OU="System"

# ETCD 安装存储目录
ETCD_HOME_PATH="${TOTAL_PATH}/etcd"
ETCD_CONF_DIR="${ETCD_HOME_PATH}/conf"
ETCD_DATA_DIR="${ETCD_HOME_PATH}/data"
# ETCD MEMBER CLUSTER
ETCD_MEMBER_1_IP="192.168.23.133"
ETCD_MEMBER_1_HOSTNAMES="k8s-node1"
ETCD_MEMBER_2_IP="192.168.23.134"
ETCD_MEMBER_2_HOSTNAMES="k8s-node2"
ETCD_MEMBER_3_IP="192.168.23.135"
ETCD_MEMBER_3_HOSTNAMES="k8s-node3"
# ETCD 集群通信地址和端口
ETCD_NITIAL_CLUSTER="${ETCD_MEMBER_1_HOSTNAMES}=https://${ETCD_MEMBER_1_IP}:2380,${ETCD_MEMBER_2_HOSTNAMES}=https://${ETCD_MEMBER_2_IP}:2380,${ETCD_MEMBER_3_HOSTNAMES}=https://${ETCD_MEMBER_3_IP}:2380"
# ETCD 集群服务地址列表
ETCD_ENDPOINTS=https://${ETCD_MEMBER_1_IP}:2379,https://${ETCD_MEMBER_2_IP}:2379,https://${ETCD_MEMBER_3_IP}:2379
# ETCD 
ETCD_PREFIX="/registry"

# Docker目录
DOCKER_HOME_DIR="${DATA_PATH}/docker"
# docker0 网卡, 说明: k8s集群不建议开启
DOCKER_NET_BRIDGE="none"

# MASTER ADDRESS
KUBE_MASTER_1_IP="192.168.23.133"
KUBE_MASTER_2_IP="192.168.23.134"
KUBE_MASTER_3_IP="192.168.23.135"
#  ADDRESSNODE
KUBE_NODE_1_IP="192.168.23.136"
KUBE_NODE_2_IP="192.168.23.137"
KUBE_NODE_3_IP="192.168.23.138"
# KUBE版本
KUBE_APP_VERSION="v1.18.8"
# 安装目录
KUBE_HOME_PATH="${TOTAL_PATH}/kubernetes-${KUBE_APP_VERSION}"
# 软连接目录
KUBE_LINK_PATH="${TOTAL_PATH}/kubernetes"
# 日志目录
KUBE_LOGS_PATH="${DATA_PATH}/logs/kubernetes"
# 集群(POD)网段
KUBE_CLUSTER_CIDR="10.240.0.0/16"
# 集群(SVC)网段
KUBE_SERVICE_CIDR="10.241.0.0/16"
# 集群(DNS)地址, 与KUBELET配置参数保持一致
KUBE_SERVICE_DNS_IP="10.241.0.254"
# 集群(SVC)地址, 一般是KUBE_SERVICE_CIDR中第一个IP
KUBE_SERVICE_SVC_IP="10.241.0.1"
# 端口范围
KUBE_PORT_RANGE="30000-65535"
# 集群DNS域名, 说明: 避免解析冲突, 不推荐使用已存在的DNS域名
KUBE_DNS_DOMAIN="linux-testing.com"
# KUBELET存储目录
KUBE_KUBELET_DIR="${DATA_PATH}/kubelet/data"
# PAUSE镜像(默认使用官方镜像, 建议改成国内地址)
KUBE_PAUSE_IMAGE="k8s.gcr.io/pause:3.2"
# Master VIP地址(SLB建议提前配置)
KUBE_CLUSTER_VIP_IP="192.168.23.133"
# Master VIP端口
KUBE_CLUSTER_VIP_PORT="6443"
# Master VIP域名
KUBE_CLUSTER_VIP_DOMAIN="kube-master.linux-testing.com"
# Master VIP模式 说明: 0、keepalived+haproxy(脚本暂时未添加ß) 1、(公有云)负载均衡器SLB
KUBE_VIP_TOOL=1
```

```sh
$ sh -x kubernetes.v1.18.sh
tree -n /tmp/palybooks
/tmp/palybooks
├── docker.yaml
├── etcd.yaml
├── invertory
│   └── hosts
├── kube-master.yaml
├── kube-node.yaml
└── roles
    ├── docker
    │   ├── tasks
    │   │   └── main.yml
    │   └── templates
    │       └── daemon.json
    ├── etcd
    │   ├── files
    │   │   ├── conf
    │   │   │   └── etcd.service
    │   │   └── ssl
    │   │       ├── ca-key.pem
    │   │       ├── ca.pem
    │   │       ├── etcd-key.pem
    │   │       └── etcd.pem
    │   ├── tasks
    │   │   └── main.yml
    │   └── templates
    │       └── etcd.conf
    ├── kube-master
    │   ├── files
    │   │   ├── bin
    │   │   │   ├── kube-apiserver
    │   │   │   ├── kube-controller-manager
    │   │   │   ├── kubectl
    │   │   │   └── kube-scheduler
    │   │   └── ssl
    │   │       ├── ca-key.pem
    │   │       ├── ca.pem
    │   │       ├── etcd-key.pem
    │   │       ├── etcd.pem
    │   │       ├── kube-apiserver-key.pem
    │   │       ├── kube-apiserver.pem
    │   │       ├── kube-controller-manager-key.pem
    │   │       ├── kube-controller-manager.pem
    │   │       ├── kubelet-key.pem
    │   │       ├── kubelet.pem
    │   │       ├── kube-proxy-key.pem
    │   │       ├── kube-proxy.pem
    │   │       ├── kube-scheduler-key.pem
    │   │       └── kube-scheduler.pem
    │   ├── tasks
    │   │   └── main.yaml
    │   └── templates
    │       ├── kube-apiserver
    │       ├── kube-apiserver.service
    │       ├── kube-config
    │       ├── kube-controller-manager
    │       ├── kube-controller-manager.kubeconfig
    │       ├── kube-controller-manager.service
    │       ├── kube-scheduler
    │       ├── kube-scheduler.kubeconfig
    │       └── kube-scheduler.service
    └── kube-node
        ├── files
        │   ├── bin
        │   │   ├── kubelet
        │   │   └── kube-proxy
        │   ├── cni
        │   │   ├── bandwidth
        │   │   ├── bridge
        │   │   ├── dhcp
        │   │   ├── firewall
        │   │   ├── flannel
        │   │   ├── host-device
        │   │   ├── host-local
        │   │   ├── ipvlan
        │   │   ├── loopback
        │   │   ├── macvlan
        │   │   ├── portmap
        │   │   ├── ptp
        │   │   ├── sbr
        │   │   ├── static
        │   │   ├── tuning
        │   │   └── vlan
        │   └── ssl
        │       ├── ca-key.pem
        │       ├── ca.pem
        │       ├── kubelet-key.pem
        │       ├── kubelet.pem
        │       ├── kube-proxy-key.pem
        │       └── kube-proxy.pem
        ├── tasks
        │   └── main.yaml
        └── templates
            ├── ipvs.modules
            ├── kube-config
            ├── kubelet
            ├── kubelet.config
            ├── kubelet.kubeconfig
            ├── kubelet.service
            ├── kube-proxy
            ├── kube-proxy.config
            ├── kube-proxy.kubeconfig
            └── kube-proxy.service

24 directories, 77 files
```

### Kubernetes 集群安装

```bash
# ansible playbooks目录
$ cd /tmp/playbooks
$ ansible-playbook etcd.yaml -i inventory/hosts
$ ansible-playbook docker.yaml -i inventory/hosts
$ ansible-playbook kube-master.yaml -i inventory/hosts
$ ansible-playbook kube-node.yaml -i inventory/hosts
```

or

```bash
$ cd /tmp/playbooks
$ ansible-playbook etcd.yaml docker.yaml kube-master.yaml kube-node.yaml -i inventory/hosts
```

### Kubernetes 集群验证

说明: ansible 一键生成脚本中默认没有开启8080端口，建议手动生成`config`文件后，执行`kubectl get node`验证集群状态


