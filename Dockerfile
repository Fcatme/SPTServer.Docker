##
## bullet's SIT LINUX Container
##

FROM debian:latest AS builder
ARG SPT=-
ARG SPT_BRANCH=3.8.1-DEV
ARG Fika=-
ARG Fika_BRANCH=main
ARG NODE=20.11.1

WORKDIR /opt

# Install git git-lfs curl
RUN apt update && apt install -yq git git-lfs curl
# Install Node Version Manager and NodeJS
RUN git clone https://github.com/nvm-sh/nvm.git $HOME/.nvm || true
RUN \. $HOME/.nvm/nvm.sh && nvm install $NODE
## Clone the SPT AKI repo or continue if it exist
RUN git clone --branch $SPT_BRANCH https://dev.sp-tarkov.com/SPT-AKI/Server.git srv || true

## Check out and git-lfs (specific commit --build-arg SPT=xxxx)
WORKDIR /opt/srv/project 
RUN git checkout $SPT || true
RUN git lfs fetch --all && git lfs pull

## Install npm dependencies and run build
RUN \. $HOME/.nvm/nvm.sh && npm install && npm run build:release -- --arch=$([ "$(uname -m)" = "aarch64" ] && echo arm64 || echo x64) --platform=linux

## Move the built server and clean up the source
RUN mv build/ /opt/server/
WORKDIR /opt
RUN rm -rf srv/

WORKDIR /opt
RUN git clone --branch $Fika_BRANCH https://github.com/project-fika/Fika-Server.git || true

WORKDIR /opt/Fika-Server
RUN \. $HOME/.nvm/nvm.sh && npm install && npm run build
RUN mkdir -p /opt/server/user/mods/fika-server/
RUN cp -r dist/* /opt/server/user/mods/fika-server/

WORKDIR /opt
RUN rm -rf Fika-Server/

FROM debian:latest
WORKDIR /opt/
RUN apt update && apt upgrade -yq && apt install -yq dos2unix
COPY --from=builder /opt/server /opt/srv
COPY start.sh /opt/start.sh
# Fix for Windows
RUN dos2unix /opt/start.sh

# Set permissions
RUN chmod o+rwx /opt /opt/srv /opt/srv/* -R

# Specify the default command to run when the container starts
CMD bash ./start.sh