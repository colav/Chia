#!/bin/bash

#moving to current dir
cd "$(dirname "$0")"

#building
docker build  --force-rm=true --no-cache=true -t colav/impactu-ui:latest .

#uploading to docker hub
docker push colav/impactu-ui:latest

#stopping current container
docker rm -f ./impactu-ui

#cleaning de old images
for i in $(docker images | grep "colav/impactu-ui" | grep -v latest | gawk -F" " '{print $3}');do docker image rm -f $i; done

#starting the new service
docker run --name impactu-ui --network host -d -it colav/impactu-ui:latest
