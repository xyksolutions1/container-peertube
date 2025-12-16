# SPDX-FileCopyrightText: © 2025 Nfrastack <code@nfrastack.com>
#
# SPDX-License-Identifier: MIT

ARG \
    BASE_IMAGE
FROM ${BASE_IMAGE}

LABEL \
        org.opencontainers.image.title="PeerTube" \
        org.opencontainers.image.description="Decntralized video hosting network" \
        org.opencontainers.image.url="https://hub.docker.com/r/nfrastack/peertube" \
        org.opencontainers.image.documentation="https://github.com/nfrastack/container-peertube/blob/main/README.md" \
        org.opencontainers.image.source="https://github.com/nfrastack/container-peertube.git" \
        org.opencontainers.image.authors="Nfrastack <code@nfrastack.com>" \
        org.opencontainers.image.vendor="Nfrastack <https://www.nfrastack.com>" \
        org.opencontainers.image.licenses="MIT"

ARG \
    PEERTUBE_VERSION="v8.0.1" \
    PEERTUBE_REPO_URL="https://github.com/Chocobozzz/PeerTube" \
    PEERTUBE_CONTAINER="PRODUCTION"

COPY CHANGELOG.md /usr/src/container/CHANGELOG.md
COPY LICENSE /usr/src/container/LICENSE
COPY README.md /usr/src/container/README.md

#COPY build-assets /build-assets

ENV \
    PEERTUBE_CONTAINER=${PEERTUBE_CONTAINER:-"PRODUCTION"} \
    NGINX_ENABLE_APPLICATION_CONFIGURATION=FALSE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_SITE_ENABLED=peertube \
    NGINX_USER=peertube \
    NGINX_GROUP=peertube \
    IMAGE_NAME="nfrastack/peertube" \
    IMAGE_REPO_URL="https://github.com/nfrastack/container-peertube/"

RUN echo "" && \
    PEERTUBE_BUILD_DEPS_ALPINE=" \
                               " \
                               && \
    PEERTUBE_RUN_DEPS_ALPINE=" \
                                ffmpeg \
                                git \
                                nodejs \
                                npm \
                                postgresql-client \
                                prosody \
                                python3 \
                                py3-pip \
                             " \
                            && \
    PEERTUBE_BUILD_DEPS_DEBIAN=" \
                                " \
                                && \
    PEERTUBE_RUN_DEPS_DEBIAN=" \
                                    ffmpeg \
                                    git \
                                    lua-unbound \
                                    nodejs \
                                    postgresql-client \
                                    python3 \
                                    python3-pip \
                                    prosody \
                                " \
                                && \
    source /container/base/functions/container/build && \
    container_build_log image && \
    create_user peertube 1000 peertube 1000 /dev/null && \
    package repo add node 22 && \
    package repo add postgres && \
    package update && \
    package upgrade && \
    package install \
                    PEERTUBE_BUILD_DEPS \
                    PEERTUBE_RUN_DEPS \
                    && \
    package build go && \
    package build yq && \
    npm install -g pnpm && \
    \
    mkdir -p /app && \
    clone_git_repo "${PEERTUBE_REPO_URL}" "${PEERTUBE_VERSION}" /usr/src/peertube && \
    build_assets src /usr/src/peertube && \
    build_assets scripts && \
    \
    pnpm install \
                --frozen-lockfile \
                && \
    npm run build && \
    \
    if [ "${PEERTUBE_CONTAINER,,}" != "production" ] ; then \
        rm -rf \
            ./client/node_modules \
            ./client/.angular \
            ./node_modules \
            ; \
        NOCLIENT=1 pnpm install \
                                --frozen-lockfile \
                                --prod \
                                --yes \
                                ; \
        \
        pnpm store prune ; \
        \
        mkdir -p /app/packages \
                 /app/client \
                 /app/dist \
                 ; \
        cp -R \
                    /usr/src/peertube/CREDITS.md \
                    /usr/src/peertube/LICENSE \
                    /usr/src/peertube/README.md \
                /app/ \
                ; \
        \
        folders="core-utils ffmpeg models node-utils transcription" ; \
        for package in \
                        core-utils \
                        ffmpeg \
                        models \
                        node-utils \
                        transcription \
                        ; do \
            mkdir -p /app/packages/"${package}" ; \
            cp -R \
                        /usr/src/peertube/packages/"${package}"/dist \
                        /usr/src/peertube/packages/"${package}"/package.json \
                    /app/packages/${package} \
                    ; \
        done ; \
        cp -R \
                    /usr/src/peertube/client/dist \
                    /usr/src/peertube/client/package.json \
                /app/client/ \
            ; \
        cp -R \
                    /usr/src/peertube/dist \
                    /usr/src/peertube/node_modules \
                    /usr/src/peertube/package.json \
                    /usr/src/peertube/yarn.lock \
                /app/ \
            ; \
    else \
        cp -R /usr/src/peertube/* /app ; \
    fi ; \
    \
    mkdir -p /container/data/peertube/config && \
    cp -R /usr/src/peertube/config/production.yaml.example /container/data/peertube/config && \
    chown -R peertube:peertube /app && \
    container_build_log add "PeerTube" "${PEERTUBE_VERSION}" "${PEERTUBE_REPO_URL}" && \
    package remove \
                    PEERTUBE_BUILD_DEPS \
                    && \
    package cleanup

EXPOSE \
        1935 \
        9000

COPY rootfs/ /
