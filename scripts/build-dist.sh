#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD_DIR_NAME="Druotic-DamageChart"
MOD_SOURCE="${ROOT}/${MOD_DIR_NAME}"
DIST_DIR="${ROOT}/dist"
ZIP_NAME="Damage Chart.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
PREVIEW_SOURCE="${ROOT}/assets/workshop_preview.png"
PREVIEW_PATH="${DIST_DIR}/workshop_preview.png"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

if [[ ! -d "${MOD_SOURCE}" ]]; then
  echo "Mod source not found: ${MOD_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${MOD_SOURCE}/manifest.json" ]]; then
  echo "Missing manifest.json in ${MOD_SOURCE}" >&2
  exit 1
fi

if [[ ! -f "${PREVIEW_SOURCE}" ]]; then
  echo "Workshop preview not found: ${PREVIEW_SOURCE}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}" "${DIST_DIR}/Druotic-DamageChart.zip"

mkdir -p "${STAGING_DIR}/mods-unpacked"
cp -R "${MOD_SOURCE}" "${STAGING_DIR}/mods-unpacked/"

(
  cd "${STAGING_DIR}"
  zip -r -q "${ZIP_PATH}" "mods-unpacked"
)

cp "${PREVIEW_SOURCE}" "${PREVIEW_PATH}"

echo "Built deploy artifacts:"
echo "  ${ZIP_PATH}"
echo "  ${PREVIEW_PATH}"
