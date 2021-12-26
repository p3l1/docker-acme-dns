FROM golang:1.13-alpine AS builder
LABEL maintainer="joona@kuori.org"

RUN apk add --update gcc musl-dev git

ENV GOPATH /tmp/buildcache
RUN git clone https://github.com/joohoi/acme-dns /tmp/acme-dns
WORKDIR /tmp/acme-dns
RUN CGO_ENABLED=1 go build

FROM alpine:latest
WORKDIR /var/lib/acme-dns/

RUN apk --no-cache add \
        ca-certificates \
        bind-tools \
        libcap && \
        update-ca-certificates && \
        rm -rf /var/cache/apk/*

COPY --from=builder /tmp/acme-dns/acme-dns /usr/local/bin/acme-dns
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/acme-dns && \
    chmod +x /usr/local/bin/acme-dns

RUN addgroup --system --gid 1994 acme && \
    adduser --system \
            --gecos "acme-dns service" \
            --disabled-password \
            --uid 1994 \
            --ingroup acme \
            --shell /sbin/nologin \
            --home /var/lib/acme-dns/ \
            acme

USER 1994

RUN mkdir -p /var/lib/acme-dns && \
    rm -rf ./config.cfg

VOLUME ["/var/lib/acme-dns"]
ENTRYPOINT ["/usr/local/bin/acme-dns"]
EXPOSE 53 80 443
EXPOSE 53/udp
