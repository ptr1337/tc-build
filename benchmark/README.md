# Benchmarking scripts

This is a collection of various scripts around using [`hyperfine`](https://github.com/sharkdp/hyperfine) to benchmark things like compile time with different optimizations and tools.

They assume that you have an environment that can compile GCC, the Linux kernel, and LLVM. [My own list of packages for Ubuntu](https://github.com/nathanchance/scripts/blob/3ee21e21592bc7aabad7e98d9c7a6cedfee27f2b/env/generic#L15-L67) is a good stepping off point. The scripts will download a local copy of Rust and build `hyperfine` to ensure that the scripts can run without modifying your host system.
