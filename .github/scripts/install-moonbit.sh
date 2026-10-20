#!/usr/bin/env bash
set -euo pipefail
# Official 2026-10-16 snapshots. Fail closed if upstream latest changes.
# Update only after rerunning interfaces, tests and examples with the new toolchain.
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
curl -fsSL https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz -o "$work/moonbit.tar.gz"
curl -fsSL https://cli.moonbitlang.com/cores/core-latest.tar.gz -o "$work/core.tar.gz"
printf '%s  %s\n' \
  ba071fe56b641e71a8a190454c6a0f7983b5af2318f3ddafb4f6305eefe3ed55 "$work/moonbit.tar.gz" \
  91e08ef19e85bc6690a6fb80f626fe0a83984804d0064e78dc7b3909463b6dab "$work/core.tar.gz" | sha256sum --check --strict
mkdir -p "$HOME/.moon/lib"
tar -xzf "$work/moonbit.tar.gz" -C "$HOME/.moon"
tar -xzf "$work/core.tar.gz" -C "$HOME/.moon/lib"
export PATH="$HOME/.moon/bin:$PATH"
moon version | grep -F 'moon 0.1.20261016 (1af328f'
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --all
moon -C "$HOME/.moon/lib/core" bundle --warn-list -a --target wasm-gc --quiet
echo "$HOME/.moon/bin" >> "$GITHUB_PATH"
