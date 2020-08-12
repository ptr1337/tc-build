#!/usr/bin/env bash
# This hashbang is purely for shellcheck auditing, this script needs to be sourced to work

KERNEL_VER=5.8.1
KERNEL_DIR=${WORK_DIR:?}/linux-${KERNEL_VER}
KERNEL_PATCH=${TC_BLD_DIR:?}/kernel/${KERNEL_DIR##*/}-allyesconfig.patch
(
    cd "${WORK_DIR}" || exit ${?}
    curl -LSs https://cdn.kernel.org/pub/linux/kernel/v5.x/"${KERNEL_DIR##*/}".tar.xz | tar -xJf -
    if [[ -f ${KERNEL_PATCH} ]]; then
        patch -d "${KERNEL_DIR}" -p1 < "${KERNEL_PATCH}"
    fi
)
