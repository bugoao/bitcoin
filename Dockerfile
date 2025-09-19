# ---------- Build stage ----------
FROM debian:bookworm-slim AS builder

ARG CAPNP_VERSION=1.0.1

# 安装构建依赖（进一步优化：只安装必要的包）
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
    libsqlite3-dev \
    curl \
    ca-certificates \
    autoconf \
    automake \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    # 清理缓存以减小镜像大小
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 源码编译安装 Cap'n Proto
RUN curl -L https://capnproto.org/capnproto-c++-${CAPNP_VERSION}.tar.gz -o capnp.tar.gz \
    && tar zxf capnp.tar.gz \
    && cd capnproto-c++-${CAPNP_VERSION} \
    && ./configure --prefix=/usr \
    && make -j$(nproc) \
    && make install \
    && cd .. \
    && rm -rf capnproto-c++-${CAPNP_VERSION} capnp.tar.gz

# 拷贝 Bitcoin Core 源码
WORKDIR /build
COPY . .

# 构建 Bitcoin Core（进一步优化编译选项）
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
  -DENABLE_IPC=ON

# 编译并剥离调试符号
RUN cmake --build build --parallel $(nproc) \
    && strip --strip-all build/bin/bitcoind

# ---------- Runtime stage ----------
FROM debian:bookworm-slim

# 安装运行时依赖（最小化）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libzmq5 \
    libsqlite3-0 \
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

# 只暴露主网 P2P 和 RPC 端口
EXPOSE 8332 8333 18332 18333 18443 18444 28332 28333 28334 28335

ENTRYPOINT ["bitcoind"]
