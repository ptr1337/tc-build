#!/usr/bin/env bash

# Error if one command fails or a variable is unset and show every command
set -eux

# Various important folders
BENCHMARK_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
. "${BENCHMARK_DIR}"/common/folders.sh

# Download and build hyperfine
. "${BENCHMARK_DIR}"/common/hyperfine.sh

# Download or checkout the latest LLVM source
LLVM_COMMIT=llvmorg-10.0.0-rc5
. "${BENCHMARK_DIR}"/common/llvm.sh

# Benchmark LLVM compile times
BLP="${TC_BLD_DIR}/build-llvm.py --no-ccache --no-update --install-folder"
RELEASE_TC=${WORK_DIR}/llvm-release
DEBUG_TC=${WORK_DIR}/llvm-debug
RELWDEBINFO_TC=${WORK_DIR}/llvm-relwithdebinfo
MINSIZEREL_TC=${WORK_DIR}/llvm-minsizerel
${HYPERFINE} \
    --export-markdown "${WORK_DIR}"/results-llvm.md \
    --runs $(($(nproc --all) / 2)) \
    --warmup 1 \
    "${BLP} ${RELEASE_TC} --build-type=Release" \
    "${BLP} ${DEBUG_TC} --build-type=Debug" \
    "${BLP} ${RELWDEBINFO_TC} --build-type=RelWithDebInfo" \
    "${BLP} ${MINSIZEREL_TC} --build-type=MinSizeRel"

# Download kernel source
. "${BENCHMARK_DIR}"/common/kernel-src.sh

# Benchmark kernel compile times
KMAKE="make -C ${KERNEL_DIR} -j$(nproc) -s O=out defconfig all"
${HYPERFINE} \
    --export-markdown "${WORK_DIR}"/results-kernel.md \
    --runs "$(nproc --all)" \
    --prepare "rm -rf ${KERNEL_DIR}/out" \
    --warmup 1 \
    "${KMAKE} CC=${RELEASE_TC}/bin/clang LD=${RELEASE_TC}/bin/ld.lld" \
    "${KMAKE} CC=${DEBUG_TC}/bin/clang LD=${DEBUG_TC}/bin/ld.lld" \
    "${KMAKE} CC=${RELWDEBINFO_TC}/bin/clang LD=${RELWDEBINFO_TC}/bin/ld.lld" \
    "${KMAKE} CC=${MINSIZEREL_TC}/bin/clang LD=${MINSIZEREL_TC}/bin/ld.lld"
