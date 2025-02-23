#!/bin/bash

#moving to current dir
cd "$(dirname "$0")"

branch=$1

echo "===== Processing branch = $branch"
if [ "main" = "$branch" ]; then
    export GPORT=3000
    export ENV_FILE=.env.local.prod
else
    export GPORT=3080
    export ENV_FILE=.env.local.dev
fi

echo "===== Using port $GPORT"
#building
docker build  --force-rm=true --no-cache=true -t colav/impactu-ui-$branch:latest  --build-arg branch=$branch --build-arg port=$GPORT --build-arg env_file=$ENV_FILE .

#uploading to docker hub
docker push colav/impactu-ui-$branch:latest

#stopping current container
docker rm -f ./impactu-ui-$branch

#cleaning de old images
for i in $(docker images | grep "colav/impactu-ui-"$branch | grep -v latest | gawk -F" " '{print $3}');do docker image rm -f $i; done

#starting the new service
docker run --name impactu-ui-$branch --network host -d -it colav/impactu-ui-$branch:latest
