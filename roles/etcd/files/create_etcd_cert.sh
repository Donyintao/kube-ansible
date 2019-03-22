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
mkdir -p ${TMP}
cat > ${TMP}/ca-config.json << EOF
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

cat > ${TMP}/ca-csr.json << EOF 
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF


cfssl gencert -initca ${TMP}/ca-csr.json | cfssljson -bare ${TMP}/ca

# Create etcd certificate
cat > ${TMP}/etcd-csr.json << EOF
{
    "CN": "etcd",
    "hosts": [
      "127.0.0.1",
      "{{ ETCD_NODE1_ADDRESS }}",
      "{{ ETCD_NODE2_ADDRESS }}",
      "{{ ETCD_NODE3_ADDRESS }}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=${TMP}/ca.pem \
              -ca-key=${TMP}/ca-key.pem \
              -config=${TMP}/ca-config.json \
              -profile=kubernetes ${TMP}/etcd-csr.json | cfssljson -bare ${TMP}/etcd
