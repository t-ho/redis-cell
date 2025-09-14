# Build stage
FROM redis:8.2-bookworm AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /build
COPY . .

RUN cargo build --release

# Runtime stage
FROM redis:8.2-bookworm

# Copy the built module from builder stage to /etc/redis/modules/ to avoid conflicts
RUN mkdir -p /etc/redis/modules
COPY --from=builder /build/target/release/libredis_cell.so /etc/redis/modules/

# Expose Redis port
EXPOSE 6379

# Start Redis with the module loaded
CMD ["redis-server", "--loadmodule", "/etc/redis/modules/libredis_cell.so"]