# ---------- Build stage ----------
FROM debian:bookworm-slim AS builder

# 安装构建依赖（构建阶段保留 SQLite3 开发包）
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libevent-dev \
    pkg-config \
    libzmq3-dev \
    libsqlite3-dev \
    curl \
    ca-certificates \
    autoconf \
    automake \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# 构建 Bitcoin Core（禁用 IPC）
RUN cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/build \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=/build/bin \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-Os -flto -fno-exceptions -fno-rtti" \
  -DCMAKE_C_FLAGS="-Os -flto" \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DINSTALL_MAN=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTS=OFF \
  -DREDUCE_EXPORTS=ON \
  -DBUILD_WALLET_TOOL=OFF \
  -DBUILD_WALLET=OFF \
  -DBUILD_GUI=OFF \
  -DBUILD_BENCH=OFF \
  -DBUILD_UTIL=OFF \
  -DENABLE_HARDENING=ON \
  -DWITH_MINIUPNPC=OFF \
  -DWITH_NATPMP=OFF \
  -DWITH_ZMQ=ON \
  -DWITH_CCACHE=OFF \
  -DENABLE_UPNP_DEFAULT=OFF \
  -DENABLE_BIP70=OFF \
  -DENABLE_IPC=OFF
RUN cmake --build build --parallel $(nproc) \
    && strip --strip-all build/bin/bitcoind

# ---------- Runtime stage ----------
FROM debian:bookworm-slim

# 安装运行时依赖（不带 SQLite）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -r -m -d /data -U -s /bin/false bitcoin \
    && mkdir -p /data/.bitcoin \
    && chown -R bitcoin:bitcoin /data

USER bitcoin

COPY --from=builder --chown=bitcoin:bitcoin /build/bin/bitcoind /usr/local/bin/

ENV HOME=/data
VOLUME /data/.bitcoin

EXPOSE 8332 8333 18332 18333 18443 18444 28332 28333 28334 28335

ENTRYPOINT ["bitcoind"]
