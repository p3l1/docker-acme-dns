FROM golang:alpine AS builder
LABEL maintainer="joona@kuori.org"

RUN apk add --update gcc musl-dev git

ENV GOPATH /tmp/buildcache
RUN git clone --depth 1 --branch v0.8 https://github.com/joohoi/acme-dns /tmp/acme-dns
WORKDIR /tmp/acme-dns
RUN CGO_ENABLED=1 go build

FROM alpine:latest

ENV PG_HOST=host.docker.internal
ENV PG_DATABASE=acme
ENV PG_USER=acme
ENV PG_PASSWD=insecure

ENV DB_ENGINE=postgres
ENV DB_CONN_STR=postgres://$PG_USER:$PG_PASSWD@$PG_HOST/$PG_DATABASE

ENV DNS_ZONE=acme.example.org
ENV DNS_ZONE_SERVER=acme.example.org
ENV EXTERNAL_IP=0.0.0.0

ENV NS_ADMIN_MAIL=acme.example.org
ENV NOTIFICATION_MAIL=acme@example.org

WORKDIR /root/
RUN apk --no-cache add \
        ca-certificates \
        gettext \
        libcap \
        curl && \
    update-ca-certificates

COPY --from=builder /tmp/acme-dns/acme-dns /usr/local/bin/acme-dns
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/acme-dns && \
    chmod +x /usr/local/bin/acme-dns

RUN mkdir -p /var/lib/acme-dns/api-certs && \
    mkdir -p /etc/acme-dns && \
    addgroup --system --gid 1994 acme && \
    adduser --system \
            --gecos "acme-dns" \
            --disabled-password \
            --uid 1994 \
            --ingroup acme \
            --shell /sbin/nologin \
            --home /var/lib/acme-dns/ \
            acme && \
    chown -R acme:acme /var/lib/acme-dns && \
    chown -R acme:acme /etc/acme-dns

WORKDIR /etc/acme-dns
COPY --chown=acme:acme acme-dns/config/template.cfg ./

WORKDIR /var/lib/acme-dns/
COPY --chown=acme:acme docker-entrypoint.sh ./
RUN chmod +x ./docker-entrypoint.sh

USER acme
ENTRYPOINT ["sh", "-c", "/var/lib/acme-dns/docker-entrypoint.sh"]

STOPSIGNAL SIGKILL
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s \
    CMD curl -f http://localhost/health || exit 1

VOLUME ["/etc/acme-dns", "/var/lib/acme-dns/"]
EXPOSE 53 80 443
EXPOSE 53/udp
