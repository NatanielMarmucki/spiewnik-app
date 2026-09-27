#!/usr/bin/env bash
# Downloads the ObjectBox C library used by unit tests (flutter test) into lib/.
# The library is not committed (see .gitignore); run this once after cloning and on CI.
#
# The C library version must match the objectbox Dart package: the Dart bindings do not
# detect C function signature mismatches. objectbox 5.3.2 requires objectbox-c 5.3.2
# (see install.sh in objectbox-dart v5.3.2).
#
# Usage: tools/fetch_objectbox_lib.sh
# Overrides (for testing the script): OBJECTBOX_PLATFORM=linux-x64, OBJECTBOX_LIB_DIR=/some/dir
set -euo pipefail

readonly C_LIBRARY_VERSION="6.0.0-beta"
readonly DART_PACKAGE_VERSION="6.0.0-beta"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lib_dir="${OBJECTBOX_LIB_DIR:-${repo_root}/lib}"

locked_version="$(awk '/^  objectbox:$/ {found=1} found && /version:/ {gsub(/"/, "", $2); print $2; exit}' "${repo_root}/pubspec.lock")"
if [[ "${locked_version}" != "${DART_PACKAGE_VERSION}" ]]; then
  echo "Error: pubspec.lock uses objectbox ${locked_version:-<not found>}, this script is pinned to ${DART_PACKAGE_VERSION}." >&2
  echo "Update C_LIBRARY_VERSION and the checksums to the objectbox-c version required by the new package." >&2
  exit 1
fi

if [[ -n "${OBJECTBOX_PLATFORM:-}" ]]; then
  platform="${OBJECTBOX_PLATFORM}"
else
  case "$(uname -s)-$(uname -m)" in
    Darwin-*) platform="macos-universal" ;;
    Linux-x86_64) platform="linux-x64" ;;
    Linux-aarch64 | Linux-arm64) platform="linux-aarch64" ;;
    *)
      echo "Error: unsupported platform $(uname -s) $(uname -m)." >&2
      echo "Download manually from https://github.com/objectbox/objectbox-c/releases/tag/v${C_LIBRARY_VERSION}" >&2
      exit 1
      ;;
  esac
fi

# SHA-256 of the release archives, from the GitHub release metadata.
case "${platform}" in
  macos-universal)
    archive="objectbox-macos-universal.zip"
    checksum="4820f5d888261e582e3c9929391f4cee9d28f9ddb31bb4c8ef9d5d46c38687b6"
    library="libobjectbox.dylib"
    ;;
  linux-x64)
    archive="objectbox-linux-x64.tar.gz"
    checksum="863e86340a52f1942918433610bc50ce89c90d9929e23564737d58df1a69e4ff"
    library="libobjectbox.so"
    ;;
  linux-aarch64)
    archive="objectbox-linux-aarch64.tar.gz"
    checksum="6ee58ca3c78fd86509c2a8e356f1c80682820f697e8f71dda2afe2856ef266be"
    library="libobjectbox.so"
    ;;
  *)
    echo "Error: unknown OBJECTBOX_PLATFORM '${platform}' (use macos-universal, linux-x64 or linux-aarch64)." >&2
    exit 1
    ;;
esac

url="https://github.com/objectbox/objectbox-c/releases/download/v${C_LIBRARY_VERSION}/${archive}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

echo "Downloading objectbox-c ${C_LIBRARY_VERSION} (${platform})..."
curl --fail --silent --show-error --location --output "${work_dir}/${archive}" "${url}"

if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${work_dir}/${archive}" | cut -d ' ' -f 1)"
else
  actual="$(shasum -a 256 "${work_dir}/${archive}" | cut -d ' ' -f 1)"
fi
if [[ "${actual}" != "${checksum}" ]]; then
  echo "Error: checksum mismatch for ${archive}: expected ${checksum}, got ${actual}." >&2
  exit 1
fi

mkdir -p "${work_dir}/extracted"
if [[ "${archive}" == *.zip ]]; then
  unzip -q "${work_dir}/${archive}" -d "${work_dir}/extracted"
else
  tar -xzf "${work_dir}/${archive}" -C "${work_dir}/extracted"
fi

mkdir -p "${lib_dir}"
cp "${work_dir}/extracted/lib/${library}" "${lib_dir}/${library}"
echo "Installed ${lib_dir}/${library}"
