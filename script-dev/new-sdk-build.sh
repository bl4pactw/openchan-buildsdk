#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 <output: image_name> <input: dockerfile_path>"
  echo "Notice:" 
  echo "    output image_name cannot be the same as the current docker image list."
  echo "****"
  echo "Current Docker images on the system:"
  docker images
  exit 1
fi

OUTPUT_IMG_NAME=$1
INPUT_DOCKERFILE_PATH=$2

sudo docker build -t "$OUTPUT_IMG_NAME" \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  --build-arg USER=$(id -un) \
  -f "$INPUT_DOCKERFILE_PATH" .

if [ $? -eq 0 ]; then
  echo "Docker image $OUTPUT_IMG_NAME built successfully."
else
  echo "Docker image build failed."
  exit 1
fi

