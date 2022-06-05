ARG DEBIAN_VERSION=bullseye
ARG PYTHON_VERSION=3.10
ARG GO_VERSION=1.18

FROM debian:${DEBIAN_VERSION}-slim as toolbox-blank
RUN useradd --uid 1001 --user-group --no-create-home toolbox \
    && mkdir -p /opt/workshop \
    && chown -R toolbox:toolbox /opt/workshop \
    && chmod -R "0700" /opt/workshop \
    && usermod --home /opt/workshop toolbox \
    && apt-get update \
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
WORKDIR /opt/workshop

FROM toolbox-blank as kubectl-src
ARG KUBECTL_VERSION=v1.24.1
# will be moved to https://github.com/kubernetes/kubectl.git
RUN git clone --single-branch --depth 1  \
    --branch ${KUBECTL_VERSION} \
    https://github.com/kubernetes/kubernetes.git \
    /opt/workshop/kubectl

FROM golang:${GO_VERSION}-${DEBIAN_VERSION} as kubectl-builder
ENV GOSUMDB="off" \
    CGO_ENABLED=0
COPY --from=kubectl-src /opt/workshop/ /
RUN cd /kubectl/cmd/kubectl/ \
    && go build -mod readonly -o kubectl \
    && chmod +x kubectl

FROM debian:${DEBIAN_VERSION}-slim as kubectl
RUN useradd --uid 1001 --user-group --no-create-home kubectl \
    && mkdir -p /opt/workshop/.kube \
    && chown -R kubectl:kubectl /opt/workshop \
    && chmod -R "0700" /opt/workshop \
    && usermod --home /opt/workshop kubectl
COPY --from=kubectl-builder /kubectl/cmd/kubectl/kubectl /usr/bin/kubectl
USER kubectl
WORKDIR /opt/workshop

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} as ansible
ARG ANSIBLE_VERSION=5.8.0
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
    && rm -rf "/var/lib/apt/lists/*" \
    && python3 -m pip install --no-cache-dir --upgrade \
        ansible==${ANSIBLE_VERSION} \
        jmespath \
        pyvmomi \
        netaddr
USER ansible
WORKDIR /opt/workshop
