#!/bin/bash

MASTER_HOST=$1
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CA_CERT="${DIR}/ssl/ca.pem"
ADMIN_KEY="${DIR}/ssl/admin-key.pem"
ADMIN_CERT="${DIR}/ssl/admin.pem"
echo $CA_CERT

kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
