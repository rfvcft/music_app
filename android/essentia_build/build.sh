#!/bin/bash

docker build -t essentia-android .

docker create --name temp-container essentia-android sleep 10

docker cp temp-container:/build/. ../app/src/main/jniLibs

docker rm temp-container
