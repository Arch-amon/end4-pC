#!/usr/bin/env bash
# Builds qs-gamma into the cache when it is missing or older than its source, then runs it.
# Needs gcc (or cc), wayland-scanner and libwayland-client.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/qs-gamma"
bin="$out/qs-gamma"
if [[ ! -x "$bin" || "$src/qs-gamma.c" -nt "$bin" || "$src/wlr-gamma-control-unstable-v1.xml" -nt "$bin" ]]; then
    mkdir -p "$out"
    xml="$src/wlr-gamma-control-unstable-v1.xml"
    wayland-scanner client-header "$xml" "$out/wlr-gamma-control-unstable-v1-client-protocol.h"
    wayland-scanner private-code "$xml" "$out/wlr-gamma-control-unstable-v1-protocol.c"
    "${CC:-cc}" -O2 -Wall -Wextra -I"$out" -o "$bin.tmp" \
        "$src/qs-gamma.c" "$out/wlr-gamma-control-unstable-v1-protocol.c" \
        $(pkg-config --cflags --libs wayland-client 2>/dev/null || echo -lwayland-client) >&2 \
        || { echo "error build failed"; exit 1; }
    mv -f "$bin.tmp" "$bin"
fi
exec "$bin"
