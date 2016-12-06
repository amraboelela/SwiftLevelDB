#!/bin/bash

git pull
git tag -f 1.0.0
git push -f --tags
git push

#PARAM=x$1
#if [ ${PARAM} = "xclean" ] ; then
#./build clean
#else
#./build
#fi

#killall RengoServer
#./.build/debug/RengoServer > log-$(date "+%u").txt 2>&1 &
#./.build/debug/RengoServer > log.txt 2>&1 &
#disown
#sleep 1
#cat log-$(date "+%u").txt
