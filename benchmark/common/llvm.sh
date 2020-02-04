#!/usr/bin/env bash
# This hashbang is purely for shellcheck auditing, this script needs to be sourced to work

: ${LLVM_COMMIT:=llvmorg-9.0.0}
LLVM_DIR=${TC_BLD_DIR:?}/llvm-project
[[ -d ${LLVM_DIR} ]] || git clone git://github.com/llvm/llvm-project "${LLVM_DIR}"
( cd "${LLVM_DIR}" && git fetch origin && git reset --hard && git checkout "${LLVM_COMMIT}" )
