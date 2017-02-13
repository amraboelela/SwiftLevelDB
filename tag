#!/bin/bash

./build
git pull
git tag -f 1.0.0
git push -f --tags
git push
