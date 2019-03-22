#! /bin/bash

TMP="/tmp/sslTmp"

# Download CFSSL
CFSSL='/usr/local/bin/cfssl'
CFSSJSON='/usr/local/bin/cfssljson'
CFSSLCERTINFO='/usr/local/bin/cfssl-certinfo'

if [ ! -f "${CFSSL}" ]; then
    wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O ${CFSSL}
    chmod +x ${CFSSL}
fi

if [ ! -f "${CFSSJSON}" ]; then
    wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O ${CFSSJSON}
    chmod +x ${CFSSJSON}
fi

if [ ! -f "${CFSSLCERTINFO}" ]; then
    wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O ${CFSSLCERTINFO}
    chmod +x ${CFSSLCERTINFO}
fi

# Create Certificate Authority
if [ ! -f "${TMP}/ca.pem" ]; then
    cfssl gencert -initca ${TMP}/ca-csr.json | cfssljson -bare ${TMP}/ca
fi

# Create etcd certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/etcd-csr.json | cfssljson -bare ${TMP}/etcd

# Create kube-apiserver certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/kube-apiserver-csr.json | cfssljson -bare ${TMP}/kube-apiserver

# Create kube-controller-manager certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/kube-controller-manager-csr.json | cfssljson -bare ${TMP}/kube-controller-manager

# Create kube-scheduler certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/kube-scheduler-csr.json | cfssljson -bare ${TMP}/kube-scheduler

# Create kubelet certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/kubelet-csr.json | cfssljson -bare ${TMP}/kubelet

# Create kube-proxy certificate
cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/kube-proxy-csr.json | cfssljson -bare ${TMP}/kube-proxy
