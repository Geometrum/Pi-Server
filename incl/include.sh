#!/bin/bash

source incl/is_sudo.sh
source incl/config

local_ip=$(ifconfig | grep 'inet 192' | sed -e 's/^.*inet \([0-9\.]*\).*/\1/')
