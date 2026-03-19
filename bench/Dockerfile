FROM alpine:3.20

ARG VEGETA_VERSION=12.12.0
ARG GRPCURL_VERSION=1.9.1
ARG TARGETARCH=amd64

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    socat \
    coreutils \
    bc \
    && wget -qO /tmp/vegeta.tar.gz \
        "https://github.com/tsenart/vegeta/releases/download/v${VEGETA_VERSION}/vegeta_${VEGETA_VERSION}_linux_${TARGETARCH}.tar.gz" \
    && tar xzf /tmp/vegeta.tar.gz -C /usr/local/bin vegeta \
    && rm /tmp/vegeta.tar.gz \
    && wget -qO /tmp/grpcurl.tar.gz \
        "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_${TARGETARCH}.tar.gz" \
    && tar xzf /tmp/grpcurl.tar.gz -C /usr/local/bin grpcurl \
    && rm /tmp/grpcurl.tar.gz \
    && vegeta --version \
    && grpcurl --version

# Run as non-root
RUN adduser -D -u 1000 bench
USER bench

WORKDIR /bench

ENTRYPOINT ["bash"]
