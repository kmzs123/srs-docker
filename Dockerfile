FROM debian:stable AS build

ARG CONFARGS
ARG MAKEARGS
ARG INSTALLDEPENDS
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG SRS_AUTO_PACKAGER
RUN echo "BUILDPLATFORM: $BUILDPLATFORM, TARGETPLATFORM: $TARGETPLATFORM, PACKAGER: ${#SRS_AUTO_PACKAGER}, CONFARGS: ${CONFARGS}, MAKEARGS: ${MAKEARGS}, INSTALLDEPENDS: ${INSTALLDEPENDS}"

# https://serverfault.com/questions/949991/how-to-install-tzdata-on-a-ubuntu-docker-image
ENV DEBIAN_FRONTEND=noninteractive

# To use if in RUN, see https://github.com/moby/moby/issues/7281#issuecomment-389440503
# Note that only exists issue like "/bin/sh: 1: [[: not found" for Ubuntu20, no such problem in CentOS7.
SHELL ["/bin/bash", "-c"]

# Install depends tools.
RUN apt-get update && \
    apt-get install -y build-essential unzip automake pkg-config tclsh cmake && \
    rm -rf /var/lib/apt/lists/*

# Copy source code to docker.
ADD https://github.com/ossrs/srs.git /srs
WORKDIR /srs/trunk

# Build and install SRS.
# Note that SRT is enabled by default, so we configure without --srt=on.
# Note that we have copied all files by make install.
RUN ./configure ${CONFARGS} && make ${MAKEARGS} && make install

############################################################
# dist
############################################################
FROM debian:stable-slim AS dist

ARG BUILDPLATFORM
ARG TARGETPLATFORM
RUN echo "BUILDPLATFORM: $BUILDPLATFORM, TARGETPLATFORM: $TARGETPLATFORM"

# Expose ports for streaming @see https://github.com/ossrs/srs#ports
EXPOSE 1935 1985 8080 5060 9000 8000/udp 10080/udp

# SRS binary, config files and srs-console.
COPY --from=build /usr/local/srs /usr/local/srs
# FFMPEG
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /usr/local/srs/objs/ffmpeg/bin/ && \
    cp /usr/bin/ffmpeg /usr/local/srs/objs/ffmpeg/bin/ffmpeg

# Test the version of binaries.
RUN ldd /usr/local/srs/objs/ffmpeg/bin/ffmpeg && \
    /usr/local/srs/objs/ffmpeg/bin/ffmpeg -version && \
    ldd /usr/local/srs/objs/srs

# Default workdir and command.
WORKDIR /usr/local/srs
ENV SRS_DAEMON=off SRS_IN_DOCKER=on
CMD ["./objs/srs", "-c", "conf/docker.conf"]
