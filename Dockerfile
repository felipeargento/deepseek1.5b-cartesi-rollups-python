# syntax=docker.io/docker/dockerfile:1
FROM --platform=linux/riscv64 cartesi/python:3.10-slim-jammy

ARG MACHINE_EMULATOR_TOOLS_VERSION=0.16.1

ADD https://github.com/cartesi/machine-emulator-tools/releases/download/v${MACHINE_EMULATOR_TOOLS_VERSION}/machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb /tmp/

RUN apt-get update && \
    apt-get install -y --no-install-recommends busybox-static && \
    dpkg -i /tmp/machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb && \
    rm /tmp/machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb && \
    rm -rf /var/lib/apt/lists/*

LABEL io.cartesi.rollups.sdk_version=0.9.0
LABEL io.cartesi.rollups.ram_size=1Gi

ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends \
  git build-essential cmake libssl-dev curl ca-certificates
rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/*
useradd --create-home --user-group dapp
EOF

ENV PATH="/opt/cartesi/bin:${PATH}"
WORKDIR /opt/cartesi/dapp

COPY requirements.txt .
RUN <<EOF
set -e
pip3 install --no-cache-dir -r requirements.txt
find /usr/local/lib -type d -name __pycache__ -exec rm -r {} +
EOF

RUN <<EOF
set -e
mkdir -p /models
cd /models
curl -OL https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/blob/main/DeepSeek-R1-Distill-Qwen-1.5B-Q2_K.gguf
EOF

RUN <<EOF
set -e
git clone https://github.com/ggerganov/llama.cpp /llama.cpp
cd /llama.cpp
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DGGML_RVV=OFF
cmake --build build -v -j $(nproc)
EOF

COPY dapp.py .
ENV ROLLUP_HTTP_SERVER_URL="http://127.0.0.1:5004"

ENTRYPOINT ["rollup-init"]
CMD ["python3", "dapp.py"]
