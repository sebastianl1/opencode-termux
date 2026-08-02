#!/data/data/com.termux/files/usr/bin/bash
#
# OpenCode — Termux: actualiza el espejo self-hosted del binario
#
# Descarga el binario oficial opencode-linux-arm64 (ultima version)
# y lo sube como asset de un Release de este repositorio, para que
# install.sh pueda usarlo como fuente B (espejo propio) cuando la
# fuente oficial (vendor) no este disponible.
#
# Uso:
#   bash tools/update-mirror.sh
#
# Requisitos:
#   - gh (GitHub CLI) autenticado
#   - curl y tar
#

set -euo pipefail

REPO="sebastianl1/opencode-termux"
TAG="opencode-mirror"
ASSET="opencode-linux-arm64.tar.gz"
VENDOR_REPO="anomalyco/opencode"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

echo ">> Obteniendo la ultima version oficial desde $VENDOR_REPO ..."
version=$(curl -fsSL "https://api.github.com/repos/$VENDOR_REPO/releases/latest" \
    | grep '"tag_name"' | head -1 | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
if [ -z "$version" ]; then
    echo "ERROR: no se pudo obtener la version oficial." >&2
    exit 1
fi
echo ">> Version oficial detectada: $version"

echo ">> Descargando $ASSET (v$version) ..."
url="https://github.com/$VENDOR_REPO/releases/download/v${version}/${ASSET}"
curl -fL --retry 2 -o "$tmp_dir/$ASSET" "$url"

echo ">> Verificando que sea un tar.gz valido ..."
tar -tzf "$tmp_dir/$ASSET" >/dev/null
if ! tar -tzf "$tmp_dir/$ASSET" | grep -qx "opencode"; then
    echo "ERROR: el archivo no contiene el binario 'opencode'." >&2
    exit 1
fi

echo ">> Subiendo espejo a $REPO (release '$TAG', asset $ASSET) ..."
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$tmp_dir/$ASSET" --repo "$REPO" --clobber
else
    gh release create "$TAG" "$tmp_dir/$ASSET" --repo "$REPO" \
        --title "opencode linux-arm64 (espejo)" \
        --notes "Espejo generado por tools/update-mirror.sh del binario oficial opencode v${version}. No editar a mano."
fi

echo ">> Espejo actualizado a opencode v$version."
