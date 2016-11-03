# Installation Builder
FROM golang:1.7.3-alpine
MAINTAINER Author.io

ADD ./app /app
WORKDIR /app

RUN apk add -U git \
  && cd /app \
  && export PATH=$PATH:$GOPATH/bin \
  && go get github.com/inconshreveable/go-update \
  && go get gopkg.in/urfave/cli.v2 \
  && go get github.com/olekukonko/tablewriter \
  && apk del git \
  && rm -rf /tmp/* /var/cache/apk/*
