# Build stage
ARG BUILD_JOBS=4
FROM debian:bookworm-slim AS builder

# Install minimal build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        libboost-system-dev \
        libboost-filesystem-dev \
        libboost-thread-dev \
        libboost-chrono-dev \
        libevent-dev \
        libsqlite3-dev \
        libzmq3-dev \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Optimized build configuration for mining pool RPC node
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_CXX_FLAGS="-O3 -march=native -mtune=native" \
    -DBUILD_BITCOIND=ON \
    -DBUILD_BITCOIN_CLI=OFF \
    -DBUILD_BITCOIN_TX=OFF \
    -DBUILD_BITCOIN_UTIL=OFF \
    -DBUILD_BITCOIN_WALLET=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTS=OFF \
    -DENABLE_HARDENING=ON \
    -DENABLE_SSE41=ON \
    -DENABLE_AVX2=ON \
    -DENABLE_SHANI=ON \
    -DWITH_ZMQ=ON \
    -DWITH_UPNP=OFF \
    -DWITH_NATPMP=OFF \
    -DWITH_BENCH=OFF \
    -DWITH_GUI=OFF

# Build and install only bitcoind
RUN cmake --build build --target bitcoind --parallel ${BUILD_JOBS} && \
    cmake --install build --component bitcoind --strip

# Final stage
FROM debian:bookworm-slim

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libevent-2.1-7 \
        libevent-pthreads-2.1-7 \
        libboost-system1.74.0 \
        libboost-filesystem1.74.0 \
        libboost-thread1.74.0 \
        libboost-chrono1.74.0 \
        libzmq5 \
        libsqlite3-0 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*



# Copy only bitcoind binary
COPY --from=builder /usr/local/bin/bitcoind /usr/local/bin/

# RPC configuration
ENV HOME=/data
VOLUME /data/.bitcoin

# Expose ports
EXPOSE 8332 8333 18332 18333 18443 18444

ENTRYPOINT ["bitcoind"]
