FROM node:20-alpine

#RUN apt-get update

# installs nvm (Node Version Manager)
#RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# download and install Node.js (you may need to restart the terminal)

#RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apk add git

ARG branch next_develop

RUN git clone -b $branch  https://github.com/colav/guatquyca.git

ARG env_file

COPY $env_file /guatquyca/.env.local

WORKDIR /guatquyca

RUN rm -rf .next

RUN npm install

RUN npm run build

ARG port

ENV PORT $port
EXPOSE $port

#CMD ["npm", "run", "start","--","-p", "${port}"]

CMD ["sh", "-c", "echo port ${PORT} && npm run start -- -p ${PORT}"]
