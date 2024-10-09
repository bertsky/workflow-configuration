ARG DOCKER_BASE_IMAGE
FROM $DOCKER_BASE_IMAGE
ARG VCS_REF
ARG BUILD_DATE
LABEL \
    maintainer="https://github.com/bertsky/workflow-configuration/issues" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/bertsky/workflow-configuration" \
    org.label-schema.build-date=$BUILD_DATE

SHELL ["/bin/bash", "-c"]
WORKDIR /build/workflow-configuration

COPY ocrd-tool.json .
COPY ocrd-make ocrd-import ocrd-page-transform xsl-transform .
COPY Makefile *.mk .
COPY *.xsl .
COPY README.md .
RUN make deps-ubuntu
RUN make install VIRTUAL_ENV=/usr/local
RUN rm -fr /build/workflow-configuration

WORKDIR /data
VOLUME ["/data"]
