#!/usr/bin/env bash
# Test how much faster ld.lld makes a build

# Error if one command fails or a variable is unset and show every command
set -eux

# Folders
BENCHMARK_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
. "${BENCHMARK_DIR}"/common/folders.sh

# Download and build hyperfine
. "${BENCHMARK_DIR}"/common/hyperfine.sh

# Download LLVM source
LLVM_COMMIT=f85d63a558364dcf57efe7b37b3e99b7fd91fd5c
. "${BENCHMARK_DIR}"/common/llvm.sh
(cd "${LLVM_DIR}" &&
    git fp -1 --stdout 870094decfc9fe80c8e0a6405421b7d09b97b02b | git ap &&
    git fp -1 --stdout 01ad4c838466bd5db180608050ed8ccb3b62d136 | git ap)

# Build LLVM and binutils
rm -rf "${TC_BLD_DIR}"/install
"${TC_BLD_DIR}"/build-llvm.py --no-update
"${TC_BLD_DIR}"/build-binutils.py

# Download kernel source
. "${BENCHMARK_DIR}"/common/kernel-src.sh
curl -LSs https://lore.kernel.org/lkml/20190307091514.2489338-1-arnd@arndb.de/raw | patch -p1 --directory="${KERNEL_DIR}"

# Benchmark ld.lld linking
KCONFIG_ALLCONFIG=$(mktemp -p "${WORK_DIR}")
echo "CONFIG_CPU_BIG_ENDIAN=n" >"${KCONFIG_ALLCONFIG}"
KMAKE=(make -C "${KERNEL_DIR}" -skj"$(nproc)" -s "CC=clang" "KCONFIG_ALLCONFIG=${KCONFIG_ALLCONFIG}" "O=out")
HYPERFINE=("${HYPERFINE}" --runs "$(nproc --all)" --warmup 1)

export PATH=${TC_BLD_DIR}/install/bin:${PATH}

#########
# arm32 #
#########

ARM_KMAKE=("${KMAKE[@]}" "ARCH=arm" "CROSS_COMPILE=arm-linux-gnueabi-")
ARM_RESULTS=${WORK_DIR}/arm32
mkdir -p "${ARM_RESULTS}"

# ld.bfd and ld.lld (clean)
"${HYPERFINE[@]}" \
    --prepare "rm -rf ${KERNEL_DIR}/out" \
    --export-markdown "${ARM_RESULTS}"/clean.md \
    "${ARM_KMAKE[*]} allyesconfig all" \
    "${ARM_KMAKE[*]} LD=ld.lld allyesconfig all"

# ld.bfd (incremental)
"${ARM_KMAKE[@]}" distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${ARM_RESULTS}"/inc-ld.bfd.md \
    "${ARM_KMAKE[*]} all"

# ld.lld (incremental)
"${ARM_KMAKE[@]}" LD=ld.lld distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${ARM_RESULTS}"/inc-ld.lld.md \
    "${ARM_KMAKE[*]} LD=ld.lld all"

#########
# arm64 #
#########

ARM64_KMAKE=("${KMAKE[@]}" "ARCH=arm64" "CROSS_COMPILE=aarch64-linux-gnu-")
ARM64_RESULTS=${WORK_DIR}/arm64
mkdir -p "${ARM64_RESULTS}"

# ld.bfd and ld.lld (clean)
"${HYPERFINE[@]}" \
    --prepare "rm -rf ${KERNEL_DIR}/out" \
    --export-markdown "${ARM64_RESULTS}"/clean.md \
    "${ARM64_KMAKE[*]} allyesconfig all" \
    "${ARM64_KMAKE[*]} LD=ld.lld allyesconfig all"

# ld.bfd (incremental)
"${ARM64_KMAKE[@]}" distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${ARM64_RESULTS}"/inc-ld.bfd.md \
    "${ARM64_KMAKE[*]} all"

# ld.lld (incremental)
"${ARM64_KMAKE[@]}" LD=ld.lld distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${ARM64_RESULTS}"/inc-ld.lld.md \
    "${ARM64_KMAKE[*]} LD=ld.lld all"

#######################
# x86_64 (implicitly) #
#######################

X86_64_RESULTS=${WORK_DIR}/x86_64
mkdir -p "${X86_64_RESULTS}"

# ld.bfd and ld.lld (clean)
"${HYPERFINE[@]}" \
    --prepare "rm -rf ${KERNEL_DIR}/out" \
    --export-markdown "${X86_64_RESULTS}"/clean.md \
    "${KMAKE[*]} allyesconfig all" \
    "${KMAKE[*]} LD=ld.lld allyesconfig all"

# ld.bfd (incremental)
"${KMAKE[@]}" distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${X86_64_RESULTS}"/inc-ld.bfd.md \
    "${KMAKE[*]} all"

# ld.lld (incremental)
"${KMAKE[@]}" LD=ld.lld distclean allyesconfig all
"${HYPERFINE[@]}" \
    --prepare "touch ${KERNEL_DIR}/init/main.c" \
    --export-markdown "${X86_64_RESULTS}"/inc-ld.lld.md \
    "${KMAKE[*]} LD=ld.lld all"

# Show where final results are
. "${BENCHMARK_DIR}"/common/ending.sh
