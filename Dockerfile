# ---------- Build stage ----------
FROM debian:bookworm-slim AS builder

ARG CAPNP_VERSION=1.0.1

# 安装构建依赖（去掉 SQLite）
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    # 精确指定所需的 Boost 库
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libevent-dev \
    pkg-config \
    libzmq3-dev \
    curl \
    ca-certificates \
    autoconf \
    automake \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# （可选）如果禁用 IPC，可以不编译 Cap’n Proto
# 这里直接跳过 Cap’n Proto 源码编译步骤

# 拷贝 Bitcoin Core 源码
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

# 安装运行时依赖（去掉 SQLite）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libzmq5 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 创建非 root 用户和必要的目录结构
RUN useradd -r -m -d /data -U -s /bin/false bitcoin \
    && mkdir -p /data/.bitcoin \
    && chown -R bitcoin:bitcoin /data

USER bitcoin

# 只拷贝最终需要的 bitcoind 二进制文件
COPY --from=builder --chown=bitcoin:bitcoin /build/bin/bitcoind /usr/local/bin/

ENV HOME=/data
VOLUME /data/.bitcoin

# 暴露常用端口
EXPOSE 8332 8333 18332 18333 18443 18444 28332 28333 28334 28335

ENTRYPOINT ["bitcoind"]
