#!/usr/bin/env bash
# Taken from https://github.com/ourresearch/openalex-topic-classification
# Edited byt Colav to fit the project.
# This script shows how to build the Docker image and push it Colav dockerhub repository

# This will be used as the image on the local.
image="colav/openalex_topic_ai"

chmod +x topic_classifier/serve

docker build  -t ${image} .

docker push ${image}
