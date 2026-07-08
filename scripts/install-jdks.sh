#!/usr/bin/env bash
#
# install-jdks.sh — install Eclipse Temurin JDKs into ~/.jdks (no root needed).
#
# Fedora 44's repos only ship JDK 25/26, so this pulls the older LTS builds
# (8, 11, 17, 21) straight from Adoptium. The install paths (~/.jdks/temurin-<v>)
# are exactly what the jdt.ls `runtimes` block in init.lua auto-detects, so you
# only have to restart Neovim afterwards. JDK 25 is left to your distro package
# (/usr/lib/jvm/java-25-openjdk).
#
# Usage:
#   bash scripts/install-jdks.sh              # install the default set (8 11 17 21)
#   bash scripts/install-jdks.sh 8 17         # install only the versions you list
#
# Re-running is safe: versions already present are skipped.

set -uo pipefail

# Versions to install (override by passing them as arguments).
if [ "$#" -gt 0 ]; then
  VERSIONS=("$@")
else
  VERSIONS=(8 11 17 21)
fi

JDKS_DIR="$HOME/.jdks"
TMP="$JDKS_DIR/.tmp"
ARCH="x64" # change to 'aarch64' on ARM machines
mkdir -p "$JDKS_DIR" "$TMP"

status=0
for v in "${VERSIONS[@]}"; do
  dest="$JDKS_DIR/temurin-$v"
  if [ -x "$dest/bin/java" ]; then
    echo "=== JDK $v: already installed, skipping ($("$dest/bin/java" -version 2>&1 | head -1)) ==="
    continue
  fi

  url="https://api.adoptium.net/v3/binary/latest/$v/ga/linux/$ARCH/jdk/hotspot/normal/eclipse"
  tgz="$TMP/temurin-$v.tar.gz"
  echo "=== JDK $v: downloading from Adoptium ==="
  if ! curl -fSL --retry 3 -o "$tgz" "$url"; then
    echo "!!! JDK $v: download FAILED (is version $v available for linux/$ARCH?)"
    status=1
    continue
  fi

  echo "=== JDK $v: extracting ==="
  edir="$TMP/extract-$v"
  rm -rf "$edir"; mkdir -p "$edir"
  if ! tar -xzf "$tgz" -C "$edir"; then
    echo "!!! JDK $v: extract FAILED"
    status=1
    rm -f "$tgz"
    continue
  fi

  # Temurin tarballs contain exactly one top-level directory = the JDK home.
  top="$(find "$edir" -maxdepth 1 -mindepth 1 -type d | head -1)"
  rm -rf "$dest"
  mv "$top" "$dest"
  rm -f "$tgz"; rm -rf "$edir"

  if [ -x "$dest/bin/java" ]; then
    echo "=== JDK $v installed: $dest ($("$dest/bin/java" -version 2>&1 | head -1)) ==="
  else
    echo "!!! JDK $v: bin/java missing after install"
    status=1
  fi
done

rm -rf "$TMP"

echo
echo "=== JDKs now in $JDKS_DIR ==="
shopt -s nullglob
for d in "$JDKS_DIR"/temurin-*; do
  [ -x "$d/bin/java" ] && echo "  $d  ->  $("$d/bin/java" -version 2>&1 | head -1)"
done
echo
if [ "$status" -eq 0 ]; then
  echo "Done. Restart Neovim; jdt.ls will pick up the new runtimes automatically."
else
  echo "Finished with errors (see above)."
fi
exit "$status"
