#!/bin/bash

git pull
./build
git tag -f 1.0.0
git push -f --tags
git push
