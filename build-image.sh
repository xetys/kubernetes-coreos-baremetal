#!/bin/bash

DIR=$1
mkisofs -R -V config-2 -o ${DIR}/config.iso ${DIR}/cloud-config
