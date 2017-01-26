# Deploy kubernetes cluster on CoreOS using cloud-config

This repository contains a collection of scripts to generate cloud-config iso images, which can setup CoreOS machine to run kubernetes.

To sum up, this few files can:

* `build-images.sh`: generate a ISO image from a specific folder, which are automatically detected as cloud config from CoreOS machines
* `build-cloud-config.sh`: generate all certificates for controller, worker and the `kubectl` CLI and scaffolds a proofed cloud config, which installs either the controller or the worker configuration for CoreOS
* `configure-kubectl.sh`: configures local `kubectl` to the generated cluster


The first step is to take a look into the `certonly-tpl.yaml` file, and add one or more ssh public keys, to be able to access the machines. This step must be done before we generate our inventory.

Then, assuming we got the following machines ready:

* controller, 10.10.10.1
* worker 1, 10.10.10.2
* worker 2, 10.10.10.3
* edge router, 123.234.234.123


with CoreOS installed, the scripts can be used to generate cloud configs like this:

```
$ ./build-cloud-config.sh controller 10.10.10.1
...
$ ./build-cloud-config.sh worker1 10.10.10.2 10.10.10.1
...
$ ./build-cloud-config.sh worker2 10.10.10.3 10.10.10.1
...
$ ./build-cloud-config.sh example.com 123.234.234.123 10.10.10.1
...
```

**attention**: The machine with a public IP needs access to the 10.10.10.X network, to join the master and reach the other nodes! Using a router like pfSense can solve this.

the script will generate:

* a ssl folder, containing:
  * the TLS certificate authority keypair, which we need to create and verify other TLS certs for this k8s cluster
  * the admin keypair, we use for `kubectl`
* an inventory for each node

```
tree inventory
inventory
├── node-controller
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── apiserver.csr
│       ├── apiserver-key.pem
│       └── apiserver.pem
├── node-example.com
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── worker.csr
│       ├── worker-key.pem
│       └── worker.pem
├── node-worker1
│   ├── cloud-config
│   │   └── openstack
│   │       └── latest
│   │           └── user_data
│   ├── config.iso
│   ├── install.sh
│   └── ssl
│       ├── worker.csr
│       ├── worker-key.pem
│       └── worker.pem
└── node-worker2
    ├── cloud-config
    │   └── openstack
    │       └── latest
    │           └── user_data
    ├── config.iso
    ├── install.sh
    └── ssl
        ├── worker.csr
        ├── worker-key.pem
        └── worker.pem
```

**attention**: the etc2 setup provided with the script is very simple and working, but not suited for production, and should be reconfigured to a external etcd2 cluster.

For changes, new config images can be generated using the `build-image.sh` tool, like

```
$ ./build-image.sh inventory/node-controller
```


It is also possible to use multiple controller machines, which have to be balanced over one DNS hostname.

## More resources

Read my [blog article about deploying kubernetes](http://stytex.de/blog/2017/01/25/deploy-kubernetes-to-bare-metal-with-nginx/)
