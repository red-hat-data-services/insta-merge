FROM alpine:latest

RUN apk add --no-cache \
	bash \
	git \
	curl \
	jq \
	wget \
	tar
RUN mkdir /ghcli && \
    cd /ghcli && \
    wget https://github.com/cli/cli/releases/download/v2.58.0/gh_2.58.0_linux_386.tar.gz -O ghcli.tar.gz && \
    tar --strip-components=1 -xf ghcli.tar.gz && \
    mv /ghcli/bin/gh /usr/bin/

RUN adduser -D ci

ADD *.sh /home/ci/

RUN chmod 555 /home/ci/*.sh 

ENTRYPOINT ["/home/ci/entrypoint.sh"]
