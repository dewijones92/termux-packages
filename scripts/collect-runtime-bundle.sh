#!/bin/bash
# L1 -> L3 contract: assemble SELF-CONTAINED per-module runtime bundles from the Termux build
# prefix, so youtubedl-android (L3) can consume them directly without pulling any prebuilt
# (API-24) dependency from Termux's repo.
#
# The 4 leaf .debs (python/ffmpeg/quickjs-ng/aria2) are NOT self-contained: their shared-lib
# closure (libssl, libxml2, libx264, libc++_shared, ...) is installed into the build prefix as
# dependencies (-I) but never emitted to output/. This script resolves each consumer binary's
# FULL runtime closure from the prefix and tars one bundle per L3 module.
#
# Runs INSIDE the termux package-builder container (same one build-package.sh ran in), so the
# prefix at $TERMUX__PREFIX still holds the built packages + their extracted dependencies.
#
# Usage: scripts/collect-runtime-bundle.sh <termux-arch>   (aarch64 | x86_64)
set -euo pipefail

ARCH="${1:?usage: collect-runtime-bundle.sh <arch>}"
PREFIX="${TERMUX__PREFIX:-/data/data/com.termux/files/usr}"
LIB="$PREFIX/lib"
BIN="$PREFIX/bin"
OUT="${TERMUX_BUNDLE_OUT:-$PWD/output}"
mkdir -p "$OUT"

# Bionic / NDK libraries provided by the device — must NOT be bundled (would shadow the system).
SYSTEM_RE='^(libc|libm|libdl|liblog|libandroid|libmediandk|libGLESv[0-9]|libEGL|libOpenSLES|libvulkan|libnativewindow|libjnigraphics|libaaudio|libcamera2ndk|libneuralnetworks|libnativehelper|ld-android|libsync|libstdc\+\+)\.so'

needed_of() { readelf -d "$1" 2>/dev/null | awk -F'[][]' '/\(NEEDED\)/ {print $2}'; }

# The build prefix is unstripped (debug symbols) — the .debs are stripped at massage time, but we
# assemble from the prefix, so strip here too (cross-arch via llvm-strip). --strip-unneeded keeps
# .dynsym (needed for runtime linking) while dropping debug/local symbols.
# llvm-strip is on PATH during the build (NDK toolchain) but not in this separate exec, so locate
# it. Guard every pipe with `|| true` so set -e/pipefail doesn't kill us on a permission-denied dir.
STRIP_BIN="$(command -v llvm-strip 2>/dev/null || true)"
if [ -z "$STRIP_BIN" ]; then
  # Fast path: the Termux standalone toolchain ($TERMUX_TOPDIR/_cache/android-r*-api-*/bin).
  for c in "${HOME:-/home/builder}"/.termux-build/_cache/*/bin/llvm-strip \
           /root/.termux-build/_cache/*/bin/llvm-strip; do
    [ -x "$c" ] && { STRIP_BIN="$c"; break; }
  done
fi
if [ -z "$STRIP_BIN" ]; then
  STRIP_BIN="$( { find / -name llvm-strip -type f 2>/dev/null || true; } | head -n1 || true )"
fi
if [ -n "$STRIP_BIN" ]; then echo "strip: using $STRIP_BIN"; else echo "strip: WARNING llvm-strip not found — bundles will be unstripped"; fi
strip_elf() { [ -n "$STRIP_BIN" ] && "$STRIP_BIN" --strip-unneeded "$1" 2>/dev/null || true; }

declare -A SEEN   # realpath -> 1

# Recursively add a soname's resolved file (and its dependencies) to SEEN.
add_lib() {
  local son="$1" f real n
  [[ "$son" =~ $SYSTEM_RE ]] && return 0
  f="$LIB/$son"
  [ -e "$f" ] || return 0          # not in prefix -> assume system-provided, skip
  real="$(readlink -f "$f")"
  [ -n "${SEEN[$real]:-}" ] && return 0
  SEEN[$real]=1
  for n in $(needed_of "$real"); do add_lib "$n"; done
}

# collect <module> <withStdlib:yes|no> <loaderspec...>   loaderspec = loadername=binname
collect() {
  local module="$1" withstdlib="$2"; shift 2
  declare -gA SEEN=()              # reset closure per module
  local stage; stage="$(mktemp -d)"
  mkdir -p "$stage/usr/lib" "$stage/usr/bin"

  local spec loader binname binpath n
  for spec in "$@"; do
    loader="${spec%%=*}"; binname="${spec##*=}"; binpath="$BIN/$binname"
    [ -e "$binpath" ] || { echo "ERROR: missing $binpath" >&2; exit 1; }
    cp -a "$binpath" "$stage/usr/bin/$binname"
    for n in $(needed_of "$binpath"); do add_lib "$n"; done
  done

  # Python C extensions in lib-dynload/ dlopen their deps (libssl, libffi, ...) at import time,
  # so resolve their NEEDED too — the interpreter binary alone doesn't reference them.
  if [ "$withstdlib" = yes ]; then
    local dyn
    while IFS= read -r dyn; do
      for n in $(needed_of "$dyn"); do add_lib "$n"; done
    done < <(find "$LIB"/python3.*/lib-dynload -name '*.so' 2>/dev/null)
  fi

  # Copy each resolved real file plus every symlink alias that points at it (preserves SONAME
  # lookup, e.g. libssl.so.3 -> libssl.so.3.x).
  local real l
  for real in "${!SEEN[@]}"; do
    cp -a "$real" "$stage/usr/lib/"
    while IFS= read -r l; do
      [ "$(readlink -f "$l")" = "$real" ] && cp -a "$l" "$stage/usr/lib/" 2>/dev/null || true
    done < <(find "$LIB" -maxdepth 1 -type l)
  done

  if [ "$withstdlib" = yes ]; then
    cp -a "$LIB"/python3.* "$stage/usr/lib/" 2>/dev/null || true
    # Trim stdlib to what yt-dlp needs (mirrors what a slim runtime ships): drop the CPython test
    # suite, GUI/dev-only packages, the static-lib config dir, any .a, and __pycache__ (regenerated
    # at runtime in the writable PYTHONHOME). This is the bulk of the size after stripping.
    local pydir
    for pydir in "$stage"/usr/lib/python3.*; do
      [ -d "$pydir" ] || continue
      rm -rf "$pydir"/test "$pydir"/tests "$pydir"/idlelib "$pydir"/turtledemo \
             "$pydir"/tkinter "$pydir"/lib2to3 "$pydir"/ensurepip "$pydir"/config-* 2>/dev/null || true
    done
    find "$stage"/usr/lib/python3.* -depth -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
    find "$stage"/usr/lib/python3.* -name '*.a' -delete 2>/dev/null || true
    # CA bundle for SSL_CERT_FILE (youtubedl-android points SSL_CERT_FILE at usr/etc/tls/cert.pem).
    if [ -d "$PREFIX/etc/tls" ] || [ -d "$PREFIX/etc/ca-certificates" ]; then
      mkdir -p "$stage/usr/etc"
      [ -d "$PREFIX/etc/tls" ] && cp -a "$PREFIX/etc/tls" "$stage/usr/etc/" || true
      [ -d "$PREFIX/etc/ca-certificates" ] && cp -a "$PREFIX/etc/ca-certificates" "$stage/usr/etc/" || true
    fi
  fi

  # Strip every ELF in the staging tree (loaders, closure libs, python extension modules).
  local elf
  while IFS= read -r elf; do strip_elf "$elf"; done \
    < <(find "$stage/usr" -type f \( -name '*.so' -o -name '*.so.*' \) ; find "$stage/usr/bin" -type f)

  ( cd "$stage" && tar cf "$OUT/bundle-${module}-${ARCH}.tar" usr )
  rm -rf "$stage"
  local nlib; nlib="$(find "$stage" -name '*.so*' 2>/dev/null | wc -l || true)"
  echo "  bundle-${module}-${ARCH}.tar  ($(du -h "$OUT/bundle-${module}-${ARCH}.tar" | cut -f1), $(printf '%s' "${#SEEN[@]}") libs)"
}

echo "Assembling runtime bundles for $ARCH from $PREFIX ..."
collect python yes python=python3.13          # interpreter + libpython + stdlib + dynload deps
collect qjs    no  qjs=qjs                     # self-contained quickjs-ng
collect ffmpeg no  ffmpeg=ffmpeg ffprobe=ffprobe
collect aria2c no  aria2c=aria2c

( cd "$OUT" && sha256sum bundle-*-"$ARCH".tar | sort -k2 > "BUNDLES-SHA256-${ARCH}.txt" )
echo "Done. Bundles + BUNDLES-SHA256-${ARCH}.txt in $OUT"
