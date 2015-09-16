#!/bin/bash

set -x

#assign the name of images which will be used in stalling

#version
K8S_VERSION=1.0.5

#basic components info
ETCD_IMAGE=k8szju/etcd:2.0.12

FLANNEL_IMAGE=k8szju/flannel:0.3.0

HYPERKUBE_IMAGE=k8szju/hyper:1.0.5

APISERVER_IMAGE=k8szju/apiserver:1.0.5

REGISTRY_IMAGE=k8szju/registry:2.1.1

#addons componetns



#user info
PRIVATE_IP=10.10.105.28
PUBLIC_IP=10.10.105.28
USER=wztest
CLUSTER=wztest
PRIVATE_PORT="5000"
IFACE=eth4
HOSTDIR=/mnt


#pull the images (docker prepared or use the tar file from qiniu)
docker pull ${ETCD_IMAGE}
docker pull ${FLANNEL_IMAGE}
docker pull ${HYPERKUBE_IMAGE}
docker pull ${APISERVER_IMAGE}
docker pull ${REGISTRY_IMAGE}

#attention to load the pause image!!!
docker load -i ./image/pause.tar



