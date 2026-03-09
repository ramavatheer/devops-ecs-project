FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    aws-cli

WORKDIR /scripts

COPY . /scripts

COPY crontab /etc/crontabs/root

RUN chmod +x /scripts/*.sh

RUN mkdir /logs

CMD ["crond", "-f", "-l", "2"]
