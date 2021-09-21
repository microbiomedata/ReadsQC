FROM ubuntu:20.04

LABEL base.image="ubuntu:20.04"
LABEL dockerfile.version="1"
LABEL software="BBTools"
LABEL software.version="38.92"
LABEL description="A set of tools labeled as \"Bestus Bioinformaticus\""
LABEL website="https://jgi.doe.gov/data-and-tools/bbtools/bb-tools-user-guide/"
LABEL license="https://jgi.doe.gov/disclaimer/"
LABEL maintainer="Chienchi Lo"
LABEL maintainer.email="chienchi@lanl.gov"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y build-essential file python \
  openjdk-13-jre-headless \
  wget samtools curl && \
  apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN wget https://sourceforge.net/projects/bbmap/files/BBMap_38.92.tar.gz && \
  tar -xzf BBMap_38.92.tar.gz && \
  rm BBMap_38.92.tar.gz

ENV PATH="${PATH}:/bbmap"\
 LC_ALL=C

WORKDIR /data
