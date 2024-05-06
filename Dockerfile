FROM ocrd/core AS base
ARG VCS_REF
ARG BUILD_DATE
LABEL \
    maintainer="https://github.com/bertsky/workflow-configuration/issues" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/bertsky/workflow-configuration" \
    org.label-schema.build-date=$BUILD_DATE

SHELL ["/bin/bash", "-c"]
WORKDIR /build

COPY ocrd-tool.json .
COPY ocrd-make ocrd-import ocrd-page-transform xsl-transform .
COPY Makefile *.mk .
COPY *.xsl .
COPY README.md .
RUN make deps-ubuntu
RUN make install VIRTUAL_ENV=/usr/local
RUN rm -fr /build

WORKDIR /data
VOLUME ["/data"]
