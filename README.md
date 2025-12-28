<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

[![Build and Push Airflow Docker Image](https://github.com/colav/Chia/actions/workflows/airflow-docker.yml/badge.svg?branch=main)](https://github.com/colav/Chia/actions/workflows/airflow-docker.yml)

# Chia
Dev-Ops for Colav services


# Description
This a mono repo with devops packages for multiples colav services.

# Installation

# OS Prerequisite
Run the next command to increase the vm max_map_count
```bash
sudo sysctl -w vm.max_map_count=262144
```

## Dependencies
Docker and docker-compose is required.
* https://docs.docker.com/engine/install/ubuntu/ (or https://docs.docker.com/engine/install/debian/, etc)
* Install `docker-compose`:  
```bash
apt install docker-compose
```
or
```bash
pip install docker-compose
```

* https://docs.docker.com/engine/install/linux-postinstall/


# Usage

Please read the README of every folder to deploy the service.

# License
BSD-3-Clause License 

# Links
http://colav.udea.edu.co/

