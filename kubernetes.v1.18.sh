#! /bin/sh

###################################################################################################################################
#####cni:         wget https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
#####kubernetes:  wget https://storage.googleapis.com/kubernetes-release/release/v1.18.8/kubernetes-server-linux-amd64.tar.gz
###################################################################################################################################

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
PLAYBOOK_PATH="${TEMP_PATH}/ansible-playbook"

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
ETCD_MEMBER_1_HOSTNAME="k8s-node1"
ETCD_MEMBER_2_IP="192.168.23.134"
ETCD_MEMBER_2_HOSTNAME="k8s-node2"
ETCD_MEMBER_3_IP="192.168.23.135"
ETCD_MEMBER_3_HOSTNAME="k8s-node3"
# ETCD 集群通信地址端口
ETCD_NITIAL_CLUSTER="${ETCD_MEMBER_1_HOSTNAME}=https://${ETCD_MEMBER_1_IP}:2380,${ETCD_MEMBER_2_HOSTNAME}=https://${ETCD_MEMBER_2_IP}:2380,${ETCD_MEMBER_3_HOSTNAME}=https://${ETCD_MEMBER_3_IP}:2380"
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
KUBE_MEMBER_1_HOSTNAME="k8s-master-01"
KUBE_MASTER_2_IP="192.168.23.134"
KUBE_MEMBER_1_HOSTNAME="k8s-master-02"
KUBE_MASTER_3_IP="192.168.23.135"
KUBE_MEMBER_1_HOSTNAME="k8s-master-03"
# KUBE版本
KUBE_APP_VERSION="v1.18.8"
# 安装目录
KUBE_HOME_PATH="${TOTAL_PATH}/kubernetes-${KUBE_APP_VERSION}"
# 软连目录
KUBE_LINK_PATH="${TOTAL_PATH}/kubernetes"
# 日志目录
KUBE_LOGS_PATH="${DATA_PATH}/logs/kubernetes"
# 集群(POD)网段
KUBE_CLUSTER_CIDR="10.240.0.0/16"
# 集群(SVC)网段
KUBE_SERVICE_CIDR="10.241.0.0/16"
# 集群(SVC)地址, 一般是KUBE_SERVICE_CIDR中第一个IP
KUBE_SERVICE_SVC_IP="10.241.0.1"
# 集群(DNS)地址, 与KUBELET配置参数保持一致
KUBE_SERVICE_DNS_IP="10.241.0.2"
# 集群端口范围
KUBE_PORT_RANGE="30000-65535"
# 集群DNS域名, 说明: 避免解析冲突, 不推荐使用已存在的DNS域名
KUBE_DNS_DOMAIN="linux-testing.com"
# KUBELET存储目录
KUBE_KUBELET_DIR="${DATA_PATH}/kubelet/data"
# PAUSE镜像(默认使用官方镜像, 建议改成国内地址)
KUBE_PAUSE_IMAGE="registry.aliyuncs.com/google_containers/pause/pause:3.2"
# Master VIP地址(SLB建议提前配置)
KUBE_CLUSTER_VIP_IP="192.168.23.133"
# Master VIP端口
KUBE_CLUSTER_VIP_PORT="6443"
# Master VIP域名
KUBE_CLUSTER_VIP_DOMAIN="kube-master.linux-testing.com"
# Master VIP模式 说明: 0、keepalived+haproxy(暂时未添加) 1、(公有云)负载均衡器SLB
KUBE_VIP_TOOL=1

###################################################################################################################################
######################                                     Download file                                     ######################  
###################################################################################################################################
cd ${TEMP_PATH}
# 检查CFSSL
which cfssl || wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl
which cfssljson || wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssljson
which cfssl-certinfo || wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/local/bin/cfssl-certinfo
chmod +x /usr/local/bin/cfssl*

# 下载k8s文件(需要科学上网)
if [ ! -d "kubernetes" ]; then
    wget -q https://storage.googleapis.com/kubernetes-release/release/v1.18.8/kubernetes-server-linux-amd64.tar.gz
    tar fx kubernetes-server-linux-amd64.tar.gz
fi
# 下载cni文件
if [ ! -d "cni" ]; then
    wget -q https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
    mkdir -p cni && tar fx cni-plugins-linux-amd64-v0.8.7.tgz -C cni
fi
###################################################################################################################################
######################                                 Certificate Authority                                 ######################  
###################################################################################################################################

# 重要的事情说三遍: 除非你了解保护 CA 使用的风险和机制, 否则生产环境不要在不同上下文中重用已经使用过的 CA
# 重要的事情说三遍: 除非你了解保护 CA 使用的风险和机制, 否则生产环境不要在不同上下文中重用已经使用过的 CA
# 重要的事情说三遍: 除非你了解保护 CA 使用的风险和机制, 否则生产环境不要在不同上下文中重用已经使用过的 CA

# 创建证书签发配置
mkdir -p ${CFSSL_PATH}
# 创建CA证书配置文件
cat << EOF | tee ${CFSSL_PATH}/ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
# 创建K8S CA证书签名请求
cat << EOF | tee ${CFSSL_PATH}/ca-csr.json 
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "${CERT_O}",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建ETCD CA证书签名请求
cat << EOF | tee ${CFSSL_PATH}/etcd-ca-csr.json 
{
  "CN": "etcd",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "${CERT_O}",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建ETCD SERVER配置文件
cat << EOF | tee ${CFSSL_PATH}/etcd-server-csr.json
{
  "CN": "etcd",
    "hosts": [
    "127.0.0.1",
    "${ETCD_MEMBER_1_IP}",
    "${ETCD_MEMBER_1_HOSTNAME}",
    "${ETCD_MEMBER_2_IP}",
    "${ETCD_MEMBER_2_HOSTNAME}",    
    "${ETCD_MEMBER_3_IP}",
    "${ETCD_MEMBER_3_HOSTNAME}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "${CERT_O}",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建ETCD CLIENT配置文件
cat << EOF | tee ${CFSSL_PATH}/etcd-client-csr.json
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${ETCD_MEMBER_1_IP}",
    "${ETCD_MEMBER_1_HOSTNAME}",
    "${ETCD_MEMBER_2_IP}",
    "${ETCD_MEMBER_2_HOSTNAME}",    
    "${ETCD_MEMBER_3_IP}",
    "${ETCD_MEMBER_3_HOSTNAME}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "${CERT_O}",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建kube-apiserver证书签名请求
cat << EOF | tee ${CFSSL_PATH}/kube-apiserver-csr.json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "${KUBE_MASTER_1_IP}",
    "${KUBE_MASTER_2_IP}",
    "${KUBE_MASTER_3_IP}",
    "${KUBE_SERVICE_SVC_IP}",
    "${KUBE_CLUSTER_VIP_IP}",
    "${KUBE_CLUSTER_VIP_DOMAIN}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.${KUBE_DNS_DOMAIN}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
    "names": [
      {
        "C": "CN",
        "ST": "$CERT_ST",
        "L": "$CERT_L",
        "O": "$CERT_O",
        "OU": "$CERT_OU"
      }
  ]
}
EOF
# 创建kube-controller-manager证书签名请求
cat << EOF | tee ${CFSSL_PATH}/kube-controller-manager-csr.json
{
  "CN": "system:kube-controller-manager",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "system:kube-controller-manager",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建kube-scheduler证书签名请求
cat << EOF | tee ${CFSSL_PATH}/kube-scheduler-csr.json
{
  "CN": "system:kube-scheduler",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "system:kube-scheduler",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建kubelet证书签名请求
cat << EOF | tee ${CFSSL_PATH}/kubelet-csr.json
{
  "CN": "kubelet",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "system:masters",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF
# 创建kube-proxy证书签名请求
cat << EOF | tee ${CFSSL_PATH}/kube-proxy-csr.json
{
  "CN": "kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "${CERT_ST}",
      "L": "${CERT_L}",
      "O": "system:node-proxier",
      "OU": "${CERT_OU}"
    }
  ]
}
EOF

# 生成ETCD CA证书和私钥
cfssl gencert -initca ${CFSSL_PATH}/etcd-ca-csr.json | cfssljson -bare ${CFSSL_PATH}/etcd-ca
# 生成ETCD SERVER证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/etcd-ca.pem \
    -ca-key=${CFSSL_PATH}/etcd-ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/etcd-server-csr.json | cfssljson -bare ${CFSSL_PATH}/etcd-server
# 生成ETCD CLIENT证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/etcd-ca.pem \
    -ca-key=${CFSSL_PATH}/etcd-ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/etcd-client-csr.json | cfssljson -bare ${CFSSL_PATH}/etcd-client

# 生成K8S CA证书和私钥
cfssl gencert -initca ${CFSSL_PATH}/ca-csr.json | cfssljson -bare ${CFSSL_PATH}/ca
# 生成kube-apiserver证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/ca.pem \
    -ca-key=${CFSSL_PATH}/ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/kube-apiserver-csr.json | cfssljson -bare ${CFSSL_PATH}/kube-apiserver
# 生成kube-controller-manager证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/ca.pem \
    -ca-key=${CFSSL_PATH}/ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/kube-controller-manager-csr.json | cfssljson -bare ${CFSSL_PATH}/kube-controller-manager
# 生成kube-scheduler证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/ca.pem \
    -ca-key=${CFSSL_PATH}/ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/kube-scheduler-csr.json | cfssljson -bare ${CFSSL_PATH}/kube-scheduler
# 生成kubelet证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/ca.pem \
    -ca-key=${CFSSL_PATH}/ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/kubelet-csr.json | cfssljson -bare ${CFSSL_PATH}/kubelet
# 生成kube-proxy证书和私钥
cfssl gencert \
    -ca=${CFSSL_PATH}/ca.pem \
    -ca-key=${CFSSL_PATH}/ca-key.pem \
    -config=${CFSSL_PATH}/ca-config.json \
    -profile=kubernetes ${CFSSL_PATH}/kube-proxy-csr.json | cfssljson -bare ${CFSSL_PATH}/kube-proxy

###################################################################################################################################
######################                                     ETCD Palybook                                     ######################  
###################################################################################################################################

# 创建ETCD Palybook目录
mkdir -p ${PLAYBOOK_PATH}/roles/etcd/{files/{conf,ssl},tasks,templates}
# 拷贝ETCD ssl证书到Playbook目录
/bin/cp -rf ${CFSSL_PATH}/etcd*.pem ${PLAYBOOK_PATH}/roles/etcd/files/ssl
# 创建ETCD Palybook文件
cat << EOF | tee ${PLAYBOOK_PATH}/etcd.yaml
- name: install etcd service
  hosts: etcd
  remote_user: root
  roles:
    - etcd
  tags:
    - etcd
EOF
# 创建ETCD配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/etcd/templates/etcd.conf
#[Member]
ETCD_DATA_DIR="${ETCD_DATA_DIR}/{{ ansible_hostname }}.etcd"
ETCD_LISTEN_PEER_URLS="https://{{ ansible_eth0.ipv4.address }}:2380"
ETCD_LISTEN_CLIENT_URLS="https://127.0.0.1:2379,https://{{ ansible_eth0.ipv4.address }}:2379"
ETCD_NAME="{{ ansible_hostname }}"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://{{ ansible_eth0.ipv4.address }}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://{{ ansible_eth0.ipv4.address }}:2379"
ETCD_INITIAL_CLUSTER="${ETCD_NITIAL_CLUSTER}"
ETCD_INITIAL_CLUSTER_TOKEN="kubernetes-etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

#[Security client]
ETCD_CERT_FILE="${ETCD_CONF_DIR}/ssl/etcd-client.pem"
ETCD_KEY_FILE="${ETCD_CONF_DIR}/ssl/etcd-client-key.pem"
ETCD_TRUSTED_CA_FILE="${ETCD_CONF_DIR}/ssl/etcd-ca.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_AUTO_TLS="true"

#[Security server]
ETCD_PEER_CERT_FILE="${ETCD_CONF_DIR}/ssl/etcd-server.pem"
ETCD_PEER_KEY_FILE="${ETCD_CONF_DIR}/ssl/etcd-server-key.pem"
ETCD_PEER_TRUSTED_CA_FILE="${ETCD_CONF_DIR}/ssl/etcd-ca.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_AUTO_TLS="true"

#[Logging]
ETCD_DEBUG="false"
ETCD_LOG_PACKAGE_LEVELS="INFO"
ETCD_LOG_OUTPUT="default"
EOF
# 创建ETCD启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/etcd/files/conf/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
EnvironmentFile=-${ETCD_CONF_DIR}/etcd.conf
User=etcd
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/bin/etcd --name=\"\${ETCD_NAME}\" --data-dir=\"\${ETCD_DATA_DIR}\" --listen-client-urls=\"\${ETCD_LISTEN_CLIENT_URLS}\""
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
# 创建ETCD main文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/etcd/tasks/main.yml
- name: install etcd
  yum: pkg=etcd state=present
- name: mkdir etcd conf directory
  file:
    path: "{{ item.path }}"
    owner: etcd
    group: etcd
    mode:  "{{ item.mode }}"
    state: directory
  with_items:
    - { path: "${ETCD_DATA_DIR}", mode: "0700"}
    - { path: "${ETCD_CONF_DIR}/ssl", mode: "0755"}
- name: copy etcd ssl file
  copy: 
    src: ssl/
    dest: ${ETCD_CONF_DIR}/ssl
    owner: etcd
    group: etcd
    mode:  0600
- name: copy etcd conf file
  template:
    src:  etcd.conf
    dest: ${ETCD_CONF_DIR}/etcd.conf
    owner: etcd
    group: etcd
    mode:  0644
- name: copy etcd service file
  copy:
    src:  conf/etcd.service
    dest: /usr/lib/systemd/system/etcd.service
    owner: root
    group: root
    mode:  0644
- name: restart etcd service
  systemd:
    state: restarted
    daemon_reload: yes
    name: etcd
    enabled: yes
EOF
###################################################################################################################################
######################                                    Docker Palybook                                    ######################  
###################################################################################################################################

# 创建docker Palybook目录
mkdir -p ${PLAYBOOK_PATH}/roles/docker/{tasks,templates}
# 创建docker Playbook文件
cat << EOF | tee ${PLAYBOOK_PATH}/docker.yaml
- name: install docker service
  hosts: node
  remote_user: root
  roles:
    - docker
  tags:
    - docker
EOF
# 创建daemon.json配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/docker/templates/daemon.json
{ 
    "max-concurrent-downloads": 20,
    "data-root": "${DOCKER_HOME_DIR}/data",
    "exec-root": "${DOCKER_HOME_DIR}/root",
    "exec-opts": ["native.cgroupdriver=systemd"],
    "bridge": "${DOCKER_NET_BRIDGE}",
    "log-opts": {
        "max-size": "500M",
        "max-file": "10"
    },
    "default-ulimits": { 
        "nofile": { 
            "Name": "nofile", 
            "Hard": 1024000, 
            "Soft": 1024000
        },
        "nproc" : {
            "Name": "nproc",
            "Hard": 1024000,
            "Soft": 1024000
        },
        "core": {
            "Name": "core",
            "Hard": -1,
            "Soft": -1
        }
    }
}
EOF
# 创建Docker main文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/docker/tasks/main.yml
- name: add dokcer-ce yum repository
  yum_repository:
    name: docker-ce
    description: Docker CE Stable - \$basearch
    baseurl: https://mirrors.aliyun.com/docker-ce/linux/centos/7/\$basearch/stable
    enabled: yes
    gpgcheck: yes
    gpgkey: https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
- name: install docker-ce service
  yum: pkg=docker-ce-19.03.12-3.el7 state=present
- name: mkdir docker conf directory
  file:
    path: "{{ item.path }}"
    owner: root
    group: root
    mode:  "{{ item.mode }}"
    state: directory
  with_items:
    - { path: "/etc/docker", mode: "0755"}
    - { path: "${DOCKER_HOME_DIR}/data", mode: "0755"}
    - { path: "${DOCKER_HOME_DIR}/root", mode: "0755"}
- name: copy daemon.json into configuration directory
  template:
    src: daemon.json
    dest: "/etc/docker/daemon.json"
    owner: root
    group: root
    mode:  0644
- name: restart docker service
  systemd:
    state: restarted
    daemon_reload: yes
    name: docker
    enabled: yes
EOF
###################################################################################################################################
######################                                 Kube-master Palybook                                  ######################
###################################################################################################################################
# 创建Kube-master Palybook目录
mkdir -p ${PLAYBOOK_PATH}/roles/kube-master/{files/{bin,ssl},tasks,templates}
# 拷贝kube二进制文件Playbook目录
/bin/cp -rf ${TEMP_PATH}/kubernetes/server/bin/{kubectl,kube-apiserver,kube-controller-manager,kube-scheduler} ${PLAYBOOK_PATH}/roles/kube-master/files/bin
# 拷贝ssl证书到Playbook目录
/bin/cp -rf ${TEMP_PATH}/cfssl/{ca*.pem,kube*.pem,etcd-ca.pem,etcd-client*.pem} ${PLAYBOOK_PATH}/roles/kube-master/files/ssl
# 创建kube-master Playbook文件
cat << EOF | tee ${PLAYBOOK_PATH}/kube-master.yaml
- name: install kubernetes master service
  hosts: master
  remote_user: root
  roles:
    - kube-master
  tags:
    - kube-master
EOF
# 创建certificate config配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: `cat ${KUBE_LINK_PATH}/etc/ssl/ca.pem | base64 -w 0`
    server: https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: `cat ${KUBE_LINK_PATH}/etc/ssl/kubelet.pem | base64 -w 0`
    client-key-data: `cat ${KUBE_LINK_PATH}/etc/ssl/kubelet-key.pem | base64 -w 0`
EOF
# 创建kube-config配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-config
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
###
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=false"
 
# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=1"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"
 
# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}"
EOF
# 创建kube-apiserver配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-apiserver
####
## kubernetes system config
##
## The following values are used to configure the kube-apiserver
##
####
## The address on the local server to listen to.
KUBE_API_ADDRESS="--advertise-address=0.0.0.0 --bind-address=0.0.0.0"
#
## The port on the local server to listen on.
KUBE_API_PORT="--secure-port=6443"
#
## Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=${ETCD_ENDPOINTS}"
#
## Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=${KUBE_SERVICE_CIDR}"
#
## default admission control policies
KUBE_ADMISSION_CONTROL="--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook"
#
## Add your own!
KUBE_API_ARGS="--apiserver-count=3 \\
               --target-ram-mb=180 \\
               --max-mutating-requests-inflight=2500 \\
               --max-requests-inflight=1000 \\
               --authorization-mode=Node,RBAC \\
               --anonymous-auth=false \\
               --enable-swagger-ui=true \\
               --service-node-port-range=${KUBE_PORT_RANGE} \\
               --log-dir=${KUBE_LOGS_PATH}/kube-apiserver \\
               --etcd-prefix=${ETCD_PREFIX} \\
               --etcd-cafile=${KUBE_LINK_PATH}/etc/ssl/etcd-ca.pem \\
               --etcd-certfile=${KUBE_LINK_PATH}/etc/ssl/etcd-client.pem \\
               --etcd-keyfile=${KUBE_LINK_PATH}/etc/ssl/etcd-client-key.pem \\
               --kubelet-client-certificate=${KUBE_LINK_PATH}/etc/ssl/kubelet.pem \\
               --kubelet-client-key=${KUBE_LINK_PATH}/etc/ssl/kubelet-key.pem \\
               --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \\
               --requestheader-allowed-names=kubelet \\
               --requestheader-extra-headers-prefix=X-Remote-Extra- \\
               --requestheader-group-headers=X-Remote-Group \\
               --requestheader-username-headers=X-Remote-User \\
               --requestheader-client-ca-file=${KUBE_LINK_PATH}/etc/ssl/ca.pem \\
               --proxy-client-cert-file=${KUBE_LINK_PATH}/etc/ssl/kubelet.pem \\
               --proxy-client-key-file=${KUBE_LINK_PATH}/etc/ssl/kubelet-key.pem \\
               --service-account-key-file=${KUBE_LINK_PATH}/etc/ssl/ca-key.pem \\
               --client-ca-file=${KUBE_LINK_PATH}/etc/ssl/ca.pem \\
               --tls-cert-file=${KUBE_LINK_PATH}/etc/ssl/kube-apiserver.pem \\
               --tls-private-key-file=${KUBE_LINK_PATH}/etc/ssl/kube-apiserver-key.pem"
EOF
# 创建kube-apiserver启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-apiserver.service
[Unit]
Description=Kube-apiserver Service
After=network.target
 
[Service]
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-config
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-apiserver
ExecStart=${KUBE_LINK_PATH}/bin/kube-apiserver \\
          \$KUBE_LOGTOSTDERR \\
          \$KUBE_LOG_LEVEL \\
          \$KUBE_ETCD_SERVERS \\
          \$KUBE_API_ADDRESS \\
          \$KUBE_API_PORT \\
          \$KUBE_ALLOW_PRIV \\
          \$KUBE_SERVICE_ADDRESSES \\
          \$KUBE_ADMISSION_CONTROL \\
          \$KUBE_API_ARGS
 
Restart=on-failure
Type=notify
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
# 创建kube-controller-manager配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-controller-manager
###
# The following values are used to configure the kubernetes controller-manager
 
# defaults from config and apiserver should be adequate
### 
# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS=--address=0.0.0.0 \\
                             --leader-elect=true \\
                             --cluster-name=kubernetes \\
                             --cluster-cidr=${KUBE_CLUSTER_CIDR} \\
                             --use-service-account-credentials=true \\
                             --log-dir=${KUBE_LOGS_PATH}/kube-controller-manager \\
                             --root-ca-file=${KUBE_LINK_PATH}/etc/ssl/ca.pem \\
                             --service-account-private-key-file=${KUBE_LINK_PATH}/etc/ssl/ca-key.pem \\
                             --cluster-signing-cert-file=${KUBE_LINK_PATH}/etc/ssl/ca.pem \\
                             --cluster-signing-key-file=${KUBE_LINK_PATH}/etc/ssl/ca-key.pem \\
                             --kubeconfig=${KUBE_LINK_PATH}/etc/kube-controller-manager.kubeconfig
EOF
# 创建kube-controller-manager认证文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-controller-manager.kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBE_LINK_PATH}/etc/ssl/ca.pem
    server: https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: kube-context
current-context: kube-context
users:
- name: system:kube-controller-manager
  user:
    client-certificate: ${KUBE_LINK_PATH}/etc/ssl/kube-controller-manager.pem
    client-key: ${KUBE_LINK_PATH}/etc/ssl/kube-controller-manager-key.pem
EOF
# 创建kube-controller-manager启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-controller-manager.service
[Unit]
Description=Kube-controller-manager Service
After=network.target
 
[Service]
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-config
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-controller-manager
ExecStart=${KUBE_LINK_PATH}/bin/kube-controller-manager \\
          \$KUBE_LOGTOSTDERR \\
          \$KUBE_LOG_LEVEL \\
          \$KUBE_MASTER \\
          \$KUBE_CONTROLLER_MANAGER_ARGS
 
Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
# 创建kube-scheduler配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-scheduler
###
# kubernetes scheduler config
 
# default config should be adequate
###
 
# Add your own!
KUBE_SCHEDULER_ARGS="--address=0.0.0.0 \
                     --leader-elect=true \
                     --log-dir=${KUBE_LOGS_PATH}/kube-scheduler \
                     --kubeconfig=${KUBE_LINK_PATH}/etc/kube-scheduler.kubeconfig"
EOF
# 创建kube-scheduler认证文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-scheduler.kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBE_LINK_PATH}/etc/ssl/ca.pem
    server: https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-scheduler
  name: kube-context
current-context: kube-context
users:
- name: system:kube-scheduler
  user:
    client-certificate: ${KUBE_LINK_PATH}/etc/ssl/kube-scheduler.pem
    client-key: ${KUBE_LINK_PATH}/etc/ssl/kube-scheduler-key.pem
EOF
# 创建kube-schedulerq启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/templates/kube-scheduler.service
[Unit]
Description=kube-scheduler Service
After=network.target
 
[Service]
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-config
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-scheduler
ExecStart=${KUBE_LINK_PATH}/bin/kube-scheduler \\
          \$KUBE_LOGTOSTDERR \\
          \$KUBE_LOG_LEVEL \\
          \$KUBE_MASTER \\
          \$KUBE_SCHEDULER_ARGS
 
Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
# 
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-master/tasks/main.yaml
- name: mkdir kubernets installation and log directory
  file: 
    path: "{{ item  }}"
    owner: root
    group: root
    mode:  0755
    state: directory
  with_items:
    - "${KUBE_HOME_PATH}/bin"
    - "${KUBE_HOME_PATH}/etc/ssl"
    - "${KUBE_LOGS_PATH}/kube-apiserver"
    - "${KUBE_LOGS_PATH}/kube-controller-manager"
    - "${KUBE_LOGS_PATH}/kube-scheduler"
- name: copy the kubernetes master binary file into install directory
  copy:
    src: bin/
    dest: ${KUBE_HOME_PATH}/bin
    owner: root
    group: root
    mode:  0755
- name: copy the kubernetes master ssl file into install directory
  copy:
    src: ssl/
    dest: ${KUBE_HOME_PATH}/etc/ssl
    owner: root
    group: root
    mode:  0600
- name: create kubernetes directory link
  file:
    src: ${KUBE_HOME_PATH}
    dest: ${KUBE_LINK_PATH}
    owner: root
    group: root
    state: link
- name:  copy the kubernets master config file into install directory
  template:
    src:  "{{ item }}"
    dest: ${KUBE_LINK_PATH}/etc/{{ item }}
    owner: root
    group: root
    mode:  0644
  with_items:
    - "kube-config"
    - "kube-apiserver"
    - "kube-controller-manager"
    - "kube-controller-manager.kubeconfig"
    - "kube-scheduler"
    - "kube-scheduler.kubeconfig"
- name:  copy kubernets master scripts file into install directory
  template:
    src:  "{{ item }}"
    dest: /usr/lib/systemd/system/{{ item }}
    owner: root
    group: root
    mode:  0644
  with_items:
    - "kube-apiserver.service"
    - "kube-controller-manager.service"
    - "kube-scheduler.service"
- name: restart kubernets master service
  systemd:
    state: restarted
    daemon_reload: yes
    name: "{{ item }}"
    enabled: yes
  with_items:
    - "kube-apiserver.service"
    - "kube-controller-manager.service"
    - "kube-scheduler.service"
EOF
###################################################################################################################################
######################                                  Kube-node Palybook                                   ######################
###################################################################################################################################
# 创建Kube-node Palybook目录
mkdir -p ${PLAYBOOK_PATH}/roles/kube-node/{files/{bin,ssl},tasks,templates}
# 拷贝cni二进制文件Playbook目录
/bin/cp -rf ${TEMP_PATH}/cni ${PLAYBOOK_PATH}/roles/kube-node/files/cni
# 拷贝node二进制文件Playbook目录
/bin/cp -rf ${TEMP_PATH}/kubernetes/server/bin/{kubelet,kube-proxy} ${PLAYBOOK_PATH}/roles/kube-node/files/bin
# 拷贝ssl证书到Playbook目录
/bin/cp -rf ${TEMP_PATH}/cfssl/{ca*.pem,kubelet*.pem,kube-proxy*.pem} ${PLAYBOOK_PATH}/roles/kube-node/files/ssl
# 创建kube-master Playbook文件
cat << EOF | tee ${PLAYBOOK_PATH}/kube-node.yaml
- name: install kubernetes node service
  hosts: node
  remote_user: root
  roles:
    - kube-node
  tags:
    - kube-node
EOF
# 创建kube-config配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kube-config
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
###
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=false"
 
# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=1"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"
 
# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}"
EOF
# 创建kubelet配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kubelet
####
## kubernetes kubelet config
####
## You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override={{ ansible_hostname }}"
#
## pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=${KUBE_PAUSE_IMAGE}"
#
## Add your own!
KUBELET_ARGS="--root-dir=${KUBE_KUBELET_DIR} \\
              --log-dir=${KUBE_LOGS_PATH}/kubelet \\
              --cert-dir=${KUBE_LINK_PATH}/etc/ssl \\
              --config=${KUBE_LINK_PATH}/etc/kubelet.config \\
              --kubeconfig=${KUBE_LINK_PATH}/etc/kubelet.kubeconfig"
EOF
# 创建kubelet.config配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kubelet.config
apiVersion: kubelet.config.k8s.io/v1beta1
address: {{ ansible_eth0.ipv4.address }}
port: 10250
cgroupDriver: systemd
clusterDNS:
- ${KUBE_SERVICE_DNS_IP}
clusterDomain: ${KUBE_DNS_DOMAIN}
failSwapOn: false
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: ${KUBE_LINK_PATH}/etc/ssl/ca.pem
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
kind: KubeletConfiguration
maxOpenFiles: 1000000
maxPods: 200
serializeImagePulls: true
failSwapOn: false
fileCheckFrequency: 20s
hairpinMode: promiscuous-bridge
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 20s
runtimeRequestTimeout: 0s
EOF
# 创建kubelet.kubeconfig配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kubelet.kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBE_LINK_PATH}/etc/ssl/ca.pem
    server: https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:node:{{ ansible_hostname }}
  name: kube-context
current-context: kube-context
users:
- name: system:node:{{ ansible_hostname }}
  user:
    client-certificate: ${KUBE_LINK_PATH}/etc/ssl/kubelet.pem
    client-key: ${KUBE_LINK_PATH}/etc/ssl/kubelet-key.pem
EOF
# 创建kubelet启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kubelet.service
[Unit]
Description=Kubelet Service
After=network.target
 
[Service]
WorkingDirectory=${KUBE_KUBELET_DIR}
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-config
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kubelet
ExecStart=${KUBE_LINK_PATH}/bin/kubelet \\
          \$KUBE_LOGTOSTDERR \\
          \$KUBE_LOG_LEVEL \\
          \$KUBELET_API_SERVER \\
          \$KUBELET_HOSTNAME \\
          \$KUBELET_POD_INFRA_CONTAINER \\
          \$KUBELET_ARGS
 
Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
# 
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kube-proxy
####
## kubernetes proxy config
####
#
## You may leave this blank to use the actual hostname
KUBE_PROXY_HOSTNAME="--hostname-override={{ ansible_hostname }}"
#
## Add your own!
KUBE_PROXY_ARGS="--config=${KUBE_LINK_PATH}/etc/kube-proxy.config \\
                 --log-dir=${KUBE_LOGS_PATH}/kubernetes/kube-proxy"
EOF
# 创建kubelet.config配置文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kube-proxy.config
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: {{ ansible_eth0.ipv4.address }}
clientConnection:
  acceptContentTypes: ""
  burst: 10
  contentType: application/vnd.kubernetes.protobuf
  kubeconfig: ${KUBE_LINK_PATH}/etc/kube-proxy.kubeconfig
  qps: 50
clusterCIDR: ${KUBE_CLUSTER_CIDR}
configSyncPeriod: 10m0s
conntrack:
  maxPerCore: 32768
  min: 131072
  tcpCloseWaitTimeout: 1h0m0s
  tcpEstablishedTimeout: 24h0m0s
enableProfiling: false
healthzBindAddress: 0.0.0.0:10256
ipvs:
  scheduler: "rr"
  syncPeriod: 15s
  minSyncPeriod: 5s

kind: KubeProxyConfiguration
metricsBindAddress: 127.0.0.1:10249
mode: "ipvs"
nodePortAddresses: null
oomScoreAdj: -999
portRange: ""
resourceContainer: /kube-proxy
udpIdleTimeout: 250ms
EOF
# 
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kube-proxy.kubeconfig
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: ${KUBE_LINK_PATH}/etc/ssl/ca.pem
    server: https://${KUBE_CLUSTER_VIP_IP}:${KUBE_CLUSTER_VIP_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-proxy
  name: kube-context
current-context: kube-context
users:
- name: system:kube-proxy
  user:
    client-certificate: ${KUBE_LINK_PATH}/etc/ssl/kube-proxy.pem
    client-key: ${KUBE_LINK_PATH}/etc/ssl/kube-proxy-key.pem
EOF
# 
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/ipvs.modules
#!/bin/bash

ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
for kernel_module in \${ipvs_modules}; do
    /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
    if [ 0 -eq 0 ]; then
        /sbin/modprobe \${kernel_module}
    fi
done
EOF
# 创建kubelet启动文件
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/templates/kube-proxy.service
[Unit]
Description=Kube-proxy Service
After=network.target
 
[Service]
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-config
EnvironmentFile=-${KUBE_LINK_PATH}/etc/kube-proxy
ExecStart=${KUBE_LINK_PATH}/bin/kube-proxy \\
        \$KUBE_LOGTOSTDERR \\
        \$KUBE_LOG_LEVEL \\
        \$KUBE_MASTER \\
        \$KUBE_PROXY_ADDRESS \\
        \$KUBE_PROXY_HOSTNAME \\
        \$KUBE_PROXY_ARGS
 
Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
# 
cat << EOF | tee ${PLAYBOOK_PATH}/roles/kube-node/tasks/main.yaml
- name:  mkdir kubernets installation and log directory
  file: 
    path: "{{ item  }}"
    owner: root
    group: root
    mode:  0755
    state: directory
  with_items:
    - "~/.kube"
    - "/opt/cni/bin"
    - "${KUBE_KUBELET_DIR}"
    - "${KUBE_HOME_PATH}/bin"
    - "${KUBE_HOME_PATH}/etc/ssl"
    - "${KUBE_LOGS_PATH}/kubelet"
    - "${KUBE_LOGS_PATH}/kube-proxy"
- name: install ipvsadm software package
  yum:
    name:
      - conntrack-tools
      - ipvsadm
      - ipset
    state: present
- name:  copy ipvs modules file into modules directory
  template:
    src:   ipvs.modules
    dest:  /etc/sysconfig/modules/ipvs.modules
    owner: root
    group: root
    mode:  0755
- name: load ipvs module
  shell: /etc/sysconfig/modules/ipvs.modules
  args:
    executable: /bin/bash
- name: copy the kubernets cni files into install directory.
  copy:
    src:  cni/
    dest: /opt/cni/bin
    owner: root
    group: root
    mode:  0755
- name: copy the kubernetes node binary files into install directory
  copy:
    src: bin/
    dest: ${KUBE_HOME_PATH}/bin
    owner: root
    group: root
    mode:  0755
- name: copy the kubernetes node ssl files into install directory
  copy:
    src: ssl/
    dest: ${KUBE_HOME_PATH}/etc/ssl
    owner: root
    group: root
    mode:  0600
- name: create kubernetes directory link
  file:
    src: ${KUBE_HOME_PATH}
    dest: ${KUBE_LINK_PATH}
    owner: root
    group: root
    state: link
- name:  copy the kubernets node config files into install directory
  template:
    src:  "{{ item }}"
    dest: ${KUBE_LINK_PATH}/etc/{{ item }}
    owner: root
    group: root
    mode:  0644
  with_items:
    - "kube-config"
    - "kubelet"
    - "kubelet.config"
    - "kubelet.kubeconfig"
    - "kube-proxy"
    - "kube-proxy.config"
    - "kube-proxy.kubeconfig"
- name:  copy the kubernets node scripts files into system directory
  template:
    src:  "{{ item }}"
    dest: /usr/lib/systemd/system/{{ item }}
    owner: root
    group: root
    mode:  0644
  with_items:
    - "kubelet.service"
    - "kube-proxy.service"
- name: restart kubernets node service
  systemd:
    state: restarted
    daemon_reload: yes
    name: "{{ item }}"
    enabled: yes
  with_items:
    - "kubelet.service"
    - "kube-proxy.service"
EOF
###################################################################################################################################
######################                                Ansible Palybook hosts                                 ######################
###################################################################################################################################
# 创建ansible hosts文件
mkdir -p ${PLAYBOOK_PATH}/invertory
cat << EOF | tee ${PLAYBOOK_PATH}/invertory/hosts
[etcd]
${ETCD_MEMBER_1_IP}
${ETCD_MEMBER_2_IP}
${ETCD_MEMBER_3_IP}

[master]
${KUBE_MASTER_1_IP}
${KUBE_MASTER_2_IP}
${KUBE_MASTER_3_IP}

[node]
${KUBE_MASTER_1_IP}
${KUBE_MASTER_2_IP}
${KUBE_MASTER_3_IP}
EOF
