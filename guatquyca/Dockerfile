FROM node:20-alpine

#RUN apt-get update

# installs nvm (Node Version Manager)
#RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# download and install Node.js (you may need to restart the terminal)

#RUN rm /bin/sh && ln -s /bin/bash /bin/sh

RUN apk add git

RUN git clone -b next_develop https://github.com/colav/guatquyca.git

COPY .env.local /guatquyca/.env.local

WORKDIR /guatquyca


RUN npm install

RUN npm run build

ENV PORT 3090

EXPOSE $PORT

CMD ["npm", "run", "start", "--","-p","3090"]
 