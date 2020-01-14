#!/usr/bin/env bash
# This hashbang is purely for shellcheck auditing, this script needs to be sourced to work

# Download and build hyperfine
HYPERFINE=${BENCHMARK_DIR:?}/hyperfine/target/release/hyperfine
if [[ ! -f ${HYPERFINE} ]]; then (
    export RUSTUP_HOME=${BENCHMARK_DIR}/.rustup
    export CARGO_HOME=${BENCHMARK_DIR}/.cargo
    curl https://sh.rustup.rs -sSf | bash -s -- -y --no-modify-path
    . "${CARGO_HOME}"/env
    git clone git://github.com/sharkdp/hyperfine "${BENCHMARK_DIR}"/hyperfine
    cd "${BENCHMARK_DIR}"/hyperfine || exit ${?}
    cargo build --release --locked
); fi
