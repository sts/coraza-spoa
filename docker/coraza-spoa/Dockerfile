FROM --platform=$BUILDPLATFORM golang:1.18-alpine AS builder

WORKDIR /build
COPY . /build

# Download dependencies for all platforms once
RUN go mod download

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apk add --no-cache gc-dev gcc musl-dev

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
       go build -o coraza-spoa cmd/main.go

# ---
FROM alpine:3.16 AS main

LABEL org.opencontainers.image.licenses="GPL-2.0-or-later" \
      org.opencontainers.image.source="https://github.com/corazawaf/coraza-spoa" \
      org.opencontainers.image.vendor="OWASP Coraza WAF (Haproxy SPOA)" \
      org.opencontainers.image.authors="OWASP Coraza WAF Authors"

RUN apk add --no-cache tini curl

RUN mkdir -p /etc/coraza-spoa /var/log/coraza-spoa \
    && touch /var/log/coraza-spoa/audit.log \
    && touch /var/log/coraza-spoa/debug.log \
    && ln -sf /proc/1/fd/1 /var/log/coraza-spoa/error.log \
    && ln -sf /proc/1/fd/1 /var/log/coraza-spoa/server.log

COPY --from=builder /build/coraza-spoa /usr/bin/coraza-spoa
COPY --from=builder /build/docker/coraza-spoa/config.yaml /etc/coraza-spoa/config.yaml
COPY --from=builder /build/docker/coraza-spoa/coraza.conf /etc/coraza-spoa/coraza.conf
COPY --from=builder /build/docker/coraza-spoa/docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

CMD ["/usr/bin/coraza-spoa", "--config-file=/etc/coraza-spoa/config.yaml"]

# ---
FROM main AS coreruleset

ARG CORERULESET_DOWNLOAD=true
ARG CORERULESET_VERSION=4.0.0-rc1

### Install the core rule set
RUN set -xe \
    && [ ${CORERULESET_DOWNLOAD} = true ] \
    && curl -Lo crs.tgz https://github.com/coreruleset/coreruleset/archive/refs/tags/v${CORERULESET_VERSION}.tar.gz \
    && mkdir crs \
    && tar --strip-components 1 -C crs -xf crs.tgz \
    && mv crs/crs-setup.conf.example /etc/coraza-spoa/crs-setup.conf \
    && mv crs/rules /etc/coraza-spoa \
    && if [[ -d crs/plugins ]] ; then mv crs/plugins /etc/coraza-spoa ; fi \
    && rm -rf crs crs.tgz

