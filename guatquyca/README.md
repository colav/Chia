<center><img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/></center>

# impactu-devops
DevOps for impactu services



# Docker hub
To upload images to docker hub please sign in it first.
Otherwise  docker push colav/images.. will not work.

`
docker login
`

If you want only test it in local host with docker compose, login is not required.


## Building Guatquyca
This is the impactu frontend package, to build it please run the command below, but first please edit
the file `.env.local` with the respective information.

`
docker build  --force-rm=true --no-cache=true -t colav/impactu-ui:latest .
`
