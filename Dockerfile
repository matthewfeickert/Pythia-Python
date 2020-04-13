ARG BASE_IMAGE=python:3.7-slim
FROM ${BASE_IMAGE} as base

SHELL [ "/bin/bash", "-c" ]

FROM base as builder
RUN apt-get -qq -y update && \
    apt-get -qq -y install \
        gcc \
        g++ \
        zlibc \
        zlib1g-dev \
        libbz2-dev \
        wget \
        make \
        cmake \
        rsync \
        python3-dev \
        sudo && \
    apt-get -y autoclean && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt-get/lists/*

# Install built code under /copy to COPY to final image
RUN mkdir -p /copy/local

# Install HepMC
ARG HEPMC_VERSION=2.06.10
RUN mkdir /code && \
    cd /code && \
    wget http://hepmc.web.cern.ch/hepmc/releases/hepmc${HEPMC_VERSION}.tgz && \
    tar xvfz hepmc${HEPMC_VERSION}.tgz && \
    mv HepMC-${HEPMC_VERSION} src && \
    export PYTHON_MINOR_VERSION=${PYTHON_VERSION::-2} && \
    mkdir build && \
    cd build && \
    cmake \
      -DCMAKE_CXX_COMPILER=$(which g++) \
      -DCMAKE_BUILD_TYPE=Release \
      -Dbuild_docs:BOOL=OFF \
      -Dmomentum:STRING=MEV \
      -Dlength:STRING=MM \
      -DCMAKE_INSTALL_PREFIX=/copy/local \
      ../src && \
    cmake --build . -- -j$(($(nproc) - 1)) && \
    cmake --build . --target install && \
    ctest --verbose --output-on-failure && \
    rm -rf /code

# Install FastJet
ARG FASTJET_VERSION=3.3.3
RUN mkdir /code && \
    cd /code && \
    wget http://fastjet.fr/repo/fastjet-${FASTJET_VERSION}.tar.gz && \
    tar xvfz fastjet-${FASTJET_VERSION}.tar.gz && \
    cd fastjet-${FASTJET_VERSION} && \
    ./configure --help && \
    export CXX=$(which g++) && \
    export PYTHON=$(which python) && \
    ./configure \
      --prefix=/copy/local \
      --enable-pyext=yes && \
    make -j$(($(nproc) - 1)) && \
    make check && \
    make install && \
    rm -rf /code

# Install PYTHIA
ARG PYTHIA_VERSION=8301
# PYTHON_VERSION already exists in the base image
RUN mkdir /code && \
    cd /code && \
    wget http://home.thep.lu.se/~torbjorn/pythia8/pythia${PYTHIA_VERSION}.tgz && \
    tar xvfz pythia${PYTHIA_VERSION}.tgz && \
    cd pythia${PYTHIA_VERSION} && \
    ./configure --help && \
    export PYTHON_MINOR_VERSION=${PYTHON_VERSION::-2} && \
    ./configure \
      --prefix=/copy/local \
      --arch=Linux \
      --cxx=g++ \
      --with-gzip \
      --with-python-bin=/usr/local/bin \
      --with-python-lib=/usr/lib/python${PYTHON_MINOR_VERSION} \
      --with-python-include=/usr/include/python${PYTHON_MINOR_VERSION} \
      --with-hepmc=/copy/local \
      --with-hepmcversion=${HEPMC_VERSION} && \
    make -j$(($(nproc) - 1)) && \
    make install && \
    rm -rf /code

FROM base
RUN apt-get -qq -y update && \
    apt-get -qq -y install \
        g++ \
        make && \
    apt-get -y autoclean && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt-get/lists/*

# Use C.UTF-8 locale to avoid issues with ASCII encoding
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV PYTHONPATH=/usr/local/lib:$PYTHONPATH
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
COPY --from=builder /copy/local/bin /usr/local/bin
COPY --from=builder /copy/local/lib /usr/local/lib
COPY --from=builder /copy/local/include /usr/local/include
COPY --from=builder /copy/local/share /usr/local/share

WORKDIR /home/data
ENV HOME /home

ENTRYPOINT ["/bin/bash", "-l", "-c"]
CMD ["/bin/bash"]
