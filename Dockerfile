ARG DEBIAN_VERSION=bullseye
ARG PYTHON_VERSION=3.10
ARG GO_VERSION=1.18

FROM debian:${DEBIAN_VERSION}-slim as base
ARG USER=toolbox
ARG HOME=/opt/workshop
RUN useradd --uid 1001 --user-group --no-create-home toolbox \
    && mkdir -p /opt/workshop/.ssh \
    && mkdir -p /opt/workshop/.kube \
    && mkdir -p /opt/workshop/.ansible \    
    && chown -R toolbox:toolbox /opt/workshop \
    && chmod -R "0700" /opt/workshop \
    && usermod --home /opt/workshop toolbox
WORKDIR /opt/workshop

FROM base as toolbox-blank
RUN apt-get update \
    && apt-get install -y \
        git \
        make \
        curl \
        wget \
        wput \
        openssh-client \
    && rm -rf "/var/lib/apt/lists/*"

FROM toolbox-blank as toolbox
USER toolbox

FROM golang:${GO_VERSION}-${DEBIAN_VERSION} as kubectl-builder
ARG KUBECTL_VERSION="v1.24.1"
ENV GOSUMDB="off" \
    CGO_ENABLED=0
# will be moved to https://github.com/kubernetes/kubectl.git
RUN git clone --single-branch --depth 1  \
        --branch ${KUBECTL_VERSION} \
        https://github.com/kubernetes/kubernetes.git \
        /go/kubectl \
    && cd /go/kubectl/cmd/kubectl/ \
    && go build -mod readonly -o kubectl \
    && chmod +x kubectl

FROM base as kubectl
COPY --from=kubectl-builder /go/kubectl/cmd/kubectl/kubectl /usr/bin/kubectl
USER toolbox

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} as ansible
# pip index versions ansible
ARG ANSIBLE_VERSION=5.9.0
RUN useradd --uid 1001 --user-group --no-create-home ansible \
    && mkdir -p /opt/workshop/.ansible \
    && chown -R ansible:ansible /opt/workshop \
    && chmod -R "0700" /opt/workshop \
    && usermod --home /opt/workshop ansible \
    && apt-get update \
    && apt-get install -y \
        git \
        make \
        curl \
        wget \
        wput \
        openssh-client \
    && rm -rf "/var/lib/apt/lists/*"
RUN python3 -m pip install --no-cache-dir --upgrade \
        ansible==${ANSIBLE_VERSION} \
        jmespath \
        pyvmomi \
        netaddr
USER ansible
WORKDIR /opt/workshop
