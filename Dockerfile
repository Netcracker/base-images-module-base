#######################################
# Stage 1 
FROM alpine:3.20 as build

COPY build/sources.list /etc/apk/repositories
RUN apk add --update --no-cache \
    gcc \
    curl \
    musl-dev \
    python3-dev=3.12.11-r0 \
    libffi-dev \
    openssl-dev \
    py3-pip

COPY build/pip.conf /etc/pip.conf
COPY build/constraint.txt /build/constraint.txt
COPY build/requirements.txt /build/requirements.txt

RUN test -d /module/venv || python3 -m venv /module/venv
RUN source /module/venv/bin/activate \
    && pip install --upgrade pip setuptools \
    && pip install --no-cache-dir -r /build/requirements.txt
RUN curl --retry 3 --retry-connrefused --retry-delay 5 -LO https://github.com/mozilla/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 && \
    chmod +x sops-v3.9.0.linux.amd64 && \
    mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops



#######################################
# Stage 2
FROM alpine:3.20

COPY build/pip.conf /etc/pip.conf
COPY build/constraint.txt /build/constraint.txt

COPY build/sources.list /etc/apk/repositories
RUN apk add --no-cache \
    python3-dev=3.12.11-r0 \
    bash \
    ca-certificates \
    tar \
    curl \
    jq \
    yq \
    gettext \
    sed \
    age

COPY --from=build /module /module
COPY --from=build /usr/local/bin/sops /usr/local/bin/sops
COPY scripts /module/scripts

RUN addgroup ci && adduser -D -h /module/ -s /bin/bash -G ci ci && \
    chown ci:ci -R /module && \
    chmod 754 /module/scripts/* && \
    chmod +x /usr/local/bin/sops

ENV PATH=/module/venv/bin:$PATH

USER ci:ci
WORKDIR /module/scripts
#ENTRYPOINT ["/bin/bash", "-c"] # https://github.com/moby/moby/issues/3753
