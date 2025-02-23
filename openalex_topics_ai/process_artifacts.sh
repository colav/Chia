#!/bin/bash
# Copyright Grupo Colav
if [ ! -d "model" ]; then
    mkdir model
fi
if [ -f "topic_classifier_v1_artifacts.tar.gz" ]; then
    echo "File already exists. Skipping download."
else
    wget https://zenodo.org/records/10568402/files/topic_classifier_v1_artifacts.tar.gz?download=1 -O topic_classifier_v1_artifacts.tar.gz
    if [ $? -ne 0 ]; then
        echo "Failed to download model artifacts."
        exit 1
    fi
fi
if [ "$(ls -A model)" ]; then
    echo "Model directory is not empty. Skipping extraction."
    exit 0
else
    tar -xvzf topic_classifier_v1_artifacts.tar.gz -C model/
fi