#!/usr/bin/env bash
# This hashbang is purely for shellcheck auditing, this script needs to be sourced to work

KERNEL_VER=5.4
KERNEL_DIR=${WORK_DIR:?}/linux-${KERNEL_VER}
(
    cd "${WORK_DIR}" || exit ${?}
    curl -LSs https://cdn.kernel.org/pub/linux/kernel/v5.x/"${KERNEL_DIR##*/}".tar.xz | tar -xJf -
    patch -d "${KERNEL_DIR}" -p1 < "${TC_BLD_DIR:?}"/kernel/"${KERNEL_DIR##*/}"-allyesconfig.patch
)
