#!/usr/bin/env bash

# Error if one command fails or a variable is unset and show every command
set -eux

# Folders
BENCHMARK_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
. "${BENCHMARK_DIR}"/common/folders.sh

# Download and build hyperfine
. "${BENCHMARK_DIR}"/common/hyperfine.sh

# Build the latest stable GCC
GCC_VER=9.2.0
GCC_DIR=${BENCHMARK_DIR}/gcc
GCC_TC_DIR=${GCC_DIR}/${GCC_VER}/bin
(
    mkdir -p "${GCC_DIR}"

    GCC_BLD_DIR=${GCC_DIR}/build
    if [[ -d ${GCC_BLD_DIR} ]]; then
        cd "${GCC_BLD_DIR}"
        git pull
    else
        git clone git://git.infradead.org/users/segher/buildall.git "${GCC_BLD_DIR}"
        cd "${GCC_BLD_DIR}"
    fi

    GCC_SOURCE=gcc-${GCC_VER}
    [[ -d ${GCC_SOURCE} ]] || curl -LSs https://mirrors.kernel.org/gnu/gcc/${GCC_SOURCE}/${GCC_SOURCE}.tar.xz | tar -xJf -

    BINUTILS_SOURCE=binutils-2.33.1
    [[ -d ${BINUTILS_SOURCE} ]] || curl -LSs https://mirrors.kernel.org/gnu/binutils/${BINUTILS_SOURCE}.tar.xz | tar -xJf -

    # Create timert
    [[ -f timert ]] || make -j"$(nproc)"

    # Create config
    cat <<EOF > config
BINUTILS_SRC=${PWD}/${BINUTILS_SOURCE}
CHECKING=release
ECHO=/bin/echo
GCC_SRC=${PWD}/${GCC_SOURCE}
MAKEOPTS=-j$(nproc)
PREFIX=${GCC_DIR}/${GCC_VER}
EOF

    for TARGET in arm arm64 powerpc powerpc64le x86_64; do
        case ${TARGET} in
            arm) TRIPLE=arm-linux-gnueabi- ;;
            *) TRIPLE=${TARGET}-linux- ;;
        esac
        rm -rf "${TARGET}"
        [[ -f ${GCC_TC_DIR}/${TRIPLE}gcc ]] || ./build --toolchain "${TARGET}"
    done
)

# Ensure binutils are available and not benchmarked
BINUTILS_DIR=${TC_BLD_DIR}/install/bin
rm -rf "${WORK_DIR}"
"${TC_BLD_DIR}"/build-binutils.py

# Download LLVM source
. "${BENCHMARK_DIR}"/common/llvm.sh

# Benchmark the different LLVM build options
TC_BLD="${TC_BLD_DIR}/build-llvm.py --check-targets clang lld llvm --no-ccache --no-update --install-folder"
LLVM_STAGE_ONE=${WORK_DIR}/llvm-stage1
LLVM_DEFAULT=${WORK_DIR}/llvm-default
LLVM_THINLTO=${WORK_DIR}/llvm-thinlto
LLVM_LTO=${WORK_DIR}/llvm-lto
LLVM_PGO=${WORK_DIR}/llvm-pgo
LLVM_PGO_THINLTO=${WORK_DIR}/llvm-pgo-thinlto
LLVM_PGO_LTO=${WORK_DIR}/llvm-pgo-lto
"${HYPERFINE}" --export-markdown "${WORK_DIR}"/llvm-build-results.md \
               --runs 7 \
               --warmup 1 \
               "${TC_BLD} ${LLVM_STAGE_ONE} --build-stage1-only --install-stage1-only" \
               "${TC_BLD} ${LLVM_DEFAULT}" \
               "${TC_BLD} ${LLVM_THINLTO} --lto=thin" \
               "${TC_BLD} ${LLVM_LTO} --lto=full" \
               "${TC_BLD} ${LLVM_PGO} --pgo" \
               "${TC_BLD} ${LLVM_PGO_THINLTO} --lto=thin --pgo" \
               "${TC_BLD} ${LLVM_PGO_LTO} --lto=full --pgo" || exit ${?}

# Download kernel source
. "${BENCHMARK_DIR}"/common/kernel-src.sh

# Kernel build commands
MAKE="make -C ${KERNEL_DIR} -j$(nproc) O=out"
LSO_MAKE="${MAKE} CC=${LLVM_STAGE_ONE}/bin/clang LD=${LLVM_STAGE_ONE}/bin/ld.lld"
LD_MAKE="${MAKE} CC=${LLVM_DEFAULT}/bin/clang LD=${LLVM_DEFAULT}/bin/ld.lld"
LTLTO_MAKE="${MAKE} CC=${LLVM_THINLTO}/bin/clang LD=${LLVM_THINLTO}/bin/ld.lld"
LFLTO_MAKE="${MAKE} CC=${LLVM_LTO}/bin/clang LD=${LLVM_LTO}/bin/ld.lld"
LPGO_MAKE="${MAKE} CC=${LLVM_PGO}/bin/clang LD=${LLVM_PGO}/bin/ld.lld"
LPGOTLTO_MAKE="${MAKE} CC=${LLVM_PGO_THINLTO}/bin/clang LD=${LLVM_PGO_THINLTO}/bin/ld.lld"
LPGOFLTO_MAKE="${MAKE} CC=${LLVM_PGO_LTO}/bin/clang LD=${LLVM_PGO_LTO}/bin/ld.lld"

# hyperfine wrapper
function hyperfine_wrapper() {(
    while (( ${#} )); do
        case ${1} in
            "-a"|"--arch") shift; ARCH=${1} ;;
            "-c"|"--cross-compile") shift; CROSS_COMPILE=${1} ;;
            "-d"|"--defconfig") shift; DEFCONFIG=${1} ;;
            "-g"|"--gcc") shift; GCC=${GCC_TC_DIR}/${1}- ;;
            "-r"|"--results-suffix") shift; RESULTS_FILE=${WORK_DIR}/results-${1}.md ;;
        esac
        shift
    done
    [[ -z ${GCC:-} && -n ${CROSS_COMPILE:-} ]] && GCC=${GCC_TC_DIR}/${CROSS_COMPILE}-
    ARCH_OPTIONS="${ARCH:+ARCH=${ARCH} }${CROSS_COMPILE:+CROSS_COMPILE=${BINUTILS_DIR}/${CROSS_COMPILE}- }${DEFCONFIG:=defconfig} all"
    "${HYPERFINE}" --export-markdown "${RESULTS_FILE}" \
                   --prepare "rm -rf ${KERNEL_DIR}/out" \
                   --runs "$(nproc --all)" \
                   --warmup 1 \
                   "${MAKE} ${ARCH:+ARCH=${ARCH} }${GCC:+CROSS_COMPILE=${GCC} }${DEFCONFIG:=defconfig} all" \
                   "${LSO_MAKE} ${ARCH_OPTIONS}" \
                   "${LD_MAKE} ${ARCH_OPTIONS}" \
                   "${LTLTO_MAKE} ${ARCH_OPTIONS}" \
                   "${LFLTO_MAKE} ${ARCH_OPTIONS}" \
                   "${LPGO_MAKE} ${ARCH_OPTIONS}" \
                   "${LPGOTLTO_MAKE} ${ARCH_OPTIONS}" \
                   "${LPGOFLTO_MAKE} ${ARCH_OPTIONS}"
) || exit ${?}; }

# Benchmark GCC 9.2.0 vs. Clang for ARM, AArch64, PowerPC 32-bit, PowerPC 64-bit little endian, and x86_64
hyperfine_wrapper -a arm -c arm-linux-gnueabi -r arm
hyperfine_wrapper -a arm64 -c aarch64-linux-gnu -g aarch64-linux -r arm64
hyperfine_wrapper -a powerpc -c powerpc-linux-gnu -g powerpc-linux -d ppc44x_defconfig -r ppc32
hyperfine_wrapper -a powerpc -c powerpc64le-linux-gnu -g powerpc64le-linux -d powernv_defconfig -r ppc64le
hyperfine_wrapper -g x86_64-linux -r x86_64

# Show where final results are
. "${BENCHMARK_DIR}"/common/ending.sh
