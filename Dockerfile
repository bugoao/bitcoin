# ---------- Build stage ----------
FROM debian:bookworm-slim AS builder

ARG CAPNP_VERSION=1.0.1

# 安装构建依赖（包含 Cap’n Proto 编译所需工具）
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

# 源码编译安装 Cap’n Proto（保证 IPC 可用）
RUN curl -L https://capnproto.org/capnproto-c++-${CAPNP_VERSION}.tar.gz -o capnp.tar.gz \
    && tar zxf capnp.tar.gz \
    && cd capnproto-c++-${CAPNP_VERSION} \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf capnproto-c++-${CAPNP_VERSION} capnp.tar.gz

# 拷贝 Bitcoin Core 源码
WORKDIR /build
COPY . .

# 构建 Bitcoin Core（矿池专用裁剪参数）
RUN cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/build \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=/build/bin \
  -DINSTALL_MAN=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF \
  -DREDUCE_EXPORTS=ON \
  -DBUILD_UTIL=ON \
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
  -DENABLE_IPC=ON
RUN cmake --build build && strip build/bin/bitcoind

# ---------- Runtime stage ----------
FROM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libevent-extra-2.1-7 \
    libevent-pthreads-2.1-7 \
    libzmq5 \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN useradd -m -d /data bitcoin
USER bitcoin

COPY --from=builder /build/bin/bitcoind /bin

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444 28332 28333 28334 28335

ENTRYPOINT ["bitcoind"]
