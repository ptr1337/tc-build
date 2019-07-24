#!/bin/bash
# LLVM benchmarking script
# Assumes that build-binutils.py has been run with the default settings beforehand

function timer() {(
    START=$(date +%s)
    "${@}" &>/dev/null || exit ${?}
    END=$(date +%s)

    TOTAL_SECONDS=$((END - START))
    MINS=$((TOTAL_SECONDS / 60))
    HOURS=$((TOTAL_SECONDS / 3600))
    if [[ ${HOURS} -gt 0 ]]; then
        MINS=$((MINS % 60))
        STRING="${HOURS}h "
    fi
    echo "${STRING}${MINS}m $((TOTAL_SECONDS % 60))s"
) || exit ${?}; }

TC_BLD=${1:?}
TC_FOLDER=$(mktemp -d)

for PAIR in llvm-base:Base llvm-thinlto:ThinLTO llvm-lto:LTO llvm-pgo:PGO llvm-pgo-thinlto:PGO+ThinLTO llvm-pgo-lto:PGO+LTO; do
    INSTALL_FOLDER=${TC_FOLDER}/${PAIR%:*}
    BUILD_TYPE=${PAIR#*:}

    BLD_LLVM_PY=( ${TC_BLD}/build-llvm.py --install-folder "${INSTALL_FOLDER}" --no-ccache --no-update )
    case ${BUILD_TYPE} in
        "Base") ;;
        "ThinLTO") BLD_LLVM_PY=( "${BLD_LLVM_PY[@]}" --lto=thin ) ;;
        "LTO") BLD_LLVM_PY=( "${BLD_LLVM_PY[@]}" --lto=full ) ;;
        "PGO") BLD_LLVM_PY=( "${BLD_LLVM_PY[@]}" --pgo ) ;;
        "PGO+ThinLTO") BLD_LLVM_PY=( "${BLD_LLVM_PY[@]}" --pgo --lto=thin ) ;;
        "PGO+LTO") BLD_LLVM_PY=( "${BLD_LLVM_PY[@]}" --pgo --lto=full ) ;;
    esac

    echo -e "${BUILD_TYPE} LLVM build: \c"
    export PATH_OVERRIDE=${TC_BLD}/install/bin
    timer "${BLD_LLVM_PY[@]}"

    for NUM in $(seq 1 2); do
        echo -e "${BUILD_TYPE} kernel build #${NUM}: \c"
        PATH_OVERRIDE=${INSTALL_FOLDER}/bin:${PATH_OVERRIDE} timer "${TC_BLD}"/kernel/build.sh --allyesconfig
    done

    echo
done
