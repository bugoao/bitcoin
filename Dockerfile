# ---------- Build stage ----------
FROM debian:bookworm-slim AS builder

ARG CAPNP_VERSION=1.0.1

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libboost-all-dev \
    libevent-dev \
    libtool \
    pkg-config \
    libzmq3-dev \
    libsqlite3-dev \
    curl \
    git \
    autoconf \
    automake \
    libssl-dev \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L https://capnproto.org/capnproto-c++-${CAPNP_VERSION}.tar.gz -o capnp.tar.gz \
    && tar zxf capnp.tar.gz \
    && cd capnproto-c++-${CAPNP_VERSION} \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf capnproto-c++-${CAPNP_VERSION} capnp.tar.gz

WORKDIR /src
COPY . .

# 构建 Bitcoin Core
RUN cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/opt/bitcoin \
  -DINSTALL_MAN=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF \
  -DREDUCE_EXPORTS=ON \
  -DBUILD_UTIL=OFF \
  -DBUILD_WALLET_TOOL=OFF \
  -DBUILD_WALLET=OFF \
  -DBUILD_GUI=OFF \
  -DBUILD_BENCH=OFF \
  -DENABLE_HARDENING=ON \
  -DWITH_MINIUPNPC=OFF \
  -DWITH_NATPMP=OFF \
  -DWITH_ZMQ=ON \
  -DWITH_CCACHE=OFF \
  -DENABLE_UPNP_DEFAULT=OFF \
  -DENABLE_BIP70=OFF \
  -DENABLE_IPC=ON \
 && cmake --build build --parallel $(nproc) \
 && cmake --install build \
 && strip /opt/bitcoin/bin/bitcoind

# ---------- Runtime stage ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libevent-extra-2.1-7 \
    libevent-pthreads-2.1-7 \
    libzmq5 \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d /data bitcoin
USER bitcoin

COPY --from=builder --chown=bitcoin:bitcoin /opt/bitcoin/bin/bitcoind /usr/local/bin/

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444 28332 28333 28334 28335

ENTRYPOINT ["bitcoind"]
