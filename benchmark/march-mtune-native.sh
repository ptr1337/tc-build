#!/usr/bin/env bash

# Error if one command fails or a variable is unset and show every command
set -eux

# Various important folders
BENCHMARK_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
. "${BENCHMARK_DIR}"/common/folders.sh

# Download and build hyperfine
. "${BENCHMARK_DIR}"/common/hyperfine.sh

# Download or checkout the latest LLVM source
. "${BENCHMARK_DIR}"/common/llvm.sh

# Benchmark LLVM compile times
BLP="${TC_BLD_DIR}/build-llvm.py --no-ccache --no-update --install-folder"
NO_MARCH_MTUNE_NATIVE_TC=${WORK_DIR}/llvm-no-march-mtune-native
MARCH_NATIVE_TC=${WORK_DIR}/llvm-march-native
MTUNE_NATIVE_TC=${WORK_DIR}/llvm-mtune-native
${HYPERFINE} \
    --export-markdown "${WORK_DIR}"/results-llvm.md \
    --runs $(($(nproc --all) / 2)) \
    --warmup 1 \
    "${BLP} ${NO_MARCH_MTUNE_NATIVE_TC}" \
    "${BLP} ${MARCH_NATIVE_TC} --cflags='-march=native -mtune=native'" \
    "${BLP} ${MTUNE_NATIVE_TC} --cflags='-mtune=native'"

# Download kernel source
. "${BENCHMARK_DIR}"/common/kernel-src.sh

# Benchmark kernel compile times
KMAKE="make -C ${KERNEL_DIR} -j$(nproc) -s O=out defconfig all"
${HYPERFINE} \
    --export-markdown "${WORK_DIR}"/results-kernel.md \
    --runs "$(nproc --all)" \
    --prepare "rm -rf ${KERNEL_DIR}/out" \
    --warmup 1 \
    "${KMAKE} CC=${NO_MARCH_MTUNE_NATIVE_TC}/bin/clang" \
    "${KMAKE} CC=${MARCH_NATIVE_TC}/bin/clang" \
    "${KMAKE} CC=${MTUNE_NATIVE_TC}/bin/clang"

# Show where final results are
. "${BENCHMARK_DIR}"/common/ending.sh
