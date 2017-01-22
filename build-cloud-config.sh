#!/bin/bash

# help view
if [ "$#" != "2" ] && [ "$#" != "3" ]; then
	echo "usage: ./build-cloud-config.sh HOSTNAME IP [MASTER]"
	exit 1
fi

# setting vars from args
HOST=$1
IP=$2


mkdir -p inventory/node-${HOST}/ssl
echo "creating SSL keys"

# check if certificate authority exists
if [ ! -f ssl/ca.pem ]; then
  mkdir ssl/
	# create certificate authority
	openssl genrsa -out ssl/ca-key.pem 2048
  openssl req -x509 -new -nodes -key ssl/ca-key.pem -days 10000 -out ssl/ca.pem -subj "/CN=kube-ca"

	# create administrator keypair
	openssl genrsa -out ssl/admin-key.pem 2048
	openssl req -new -key ssl/admin-key.pem -out ssl/admin.csr -subj "/CN=kube-admin"
	openssl x509 -req -in ssl/admin.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out ssl/admin.pem -days 365
fi

if [ $# = "2" ]; then
	# configure master
	ADVERTISE_IP=${IP}
	NODETYPE="apiserver"
	INSTALLURL=https://raw.githubusercontent.com/coreos/coreos-kubernetes/master/multi-node/generic/controller-install.sh

	openssl genrsa -out inventory/node-${HOST}/ssl/apiserver-key.pem 2048
	IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/apiserver-key.pem -out inventory/node-${HOST}/ssl/apiserver.csr -subj "/CN=kube-apiserver" -config master-openssl.cnf
	IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/apiserver.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/apiserver.pem -days 365 -extensions v3_req -extfile master-openssl.cnf
	echo "creating CoreOS cloud-config for controller ${HOST}(${IP})"
else
	# configure worker
	ADVERTISE_IP=${IP}
	MASTER=$3
	NODETYPE="worker"
	INSTALLURL=https://raw.githubusercontent.com/coreos/coreos-kubernetes/master/multi-node/generic/worker-install.sh

	openssl genrsa -out inventory/node-${HOST}/ssl/worker-key.pem 2048
	WORKER_IP=${IP} openssl req -new -key inventory/node-${HOST}/ssl/worker-key.pem -out inventory/node-${HOST}/ssl/worker.csr -subj "/CN=${HOST}" -config worker-openssl.cnf
	WORKER_IP=${IP} openssl x509 -req -in inventory/node-${HOST}/ssl/worker.csr -CA ssl/ca.pem -CAkey ssl/ca-key.pem -CAcreateserial -out inventory/node-${HOST}/ssl/worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf
	echo "creating CoreOS cloud-config for $HOST with K8S version $K8S_VER to join $IP"
	IP=${MASTER} # for etcd2 config
fi

# create cloud config folder
mkdir -p inventory/node-${HOST}/cloud-config/openstack/latest
wget -O inventory/node-${HOST}/install.sh ${INSTALLURL}
cat inventory/node-${HOST}/install.sh | \
sed -e "s/ ETCD_ENDPOINTS=/ ETCD_ENDPOINTS=http:\/\/${IP}:2379/" | \
sed -e "s/USE_CALICO=false/USE_CALICO=true/" | \
sed -e "s/CONTROLLER_ENDPOINT=/CONTROLLER_ENDPOINT=https:\/\/${IP}/g" > inventory/node-${HOST}/install.sh

# bash templating
cat certonly-tpl.yaml | \
sed -e s/%HOST%/${HOST}/g | \
sed -e "s/%INSTALL_SCRIPT%/$(<inventory/node-${HOST}/install.sh sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%CA_PEM%/$(<ssl/ca.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%NODE_PEM%/$(<inventory/node-${HOST}/ssl/${NODETYPE}.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e "s/%NODE_KEY_PEM%/$(<inventory/node-${HOST}/ssl/${NODETYPE}-key.pem sed -e 's/\(.*\)/      \1/g' | sed -e 's/[\&/]/\\&/g' -e 's/$/\\n/' | tr -d '\n')/g" | \
sed -e s/%NODETYPE%/${NODETYPE}/g | \
sed -e s/%ADVERTISE_IP%/${ADVERTISE_IP}/g | \
sed -e s/%IP%/${IP}/g > inventory/node-${HOST}/cloud-config/openstack/latest/user_data

./build-image.sh inventory/node-${HOST}
