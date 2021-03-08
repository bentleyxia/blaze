#!/bin/bash

(docker stop blaze && docker rm blaze) > /dev/null 2>&1

HOME="$(realpath ~)"

if [ ! -d $HOME/docker ];then
    mkdir $HOME/docker
fi

docker build -t centos/dev:blaze .
docker run --name blaze -d --cap-add sys_ptrace -p 127.0.0.1:2222:22 -p 127.0.0.1:5005:5005 -P -v"$HOME/docker:/docker" -w /docker centos/dev:blaze
