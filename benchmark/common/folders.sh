#!/usr/bin/env bash
# This hashbang is purely for shellcheck auditing, this script needs to be sourced to work

TC_BLD_DIR=$(readlink -f "${BENCHMARK_DIR:?}"/..)
WORK_DIR=$(mktemp -d -p "${BENCHMARK_DIR}")
