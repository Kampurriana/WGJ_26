#!/usr/bin/env bash
# Arranque de sesión de Claude Code EN LA NUBE (Linux): instala Godot 4.7.2 si falta y deja
# GODOT apuntando a él. En un PC local (Windows/Mac) no hace nada: allí Godot se instala a mano
# y su ruta va en .claude/settings.local.json (ver INSTALAR-PARA-CLAUDE del kit).
# Idempotente: si Godot ya está y dice su versión, no descarga nada.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

VERSION="4.7.2"
ZIP="Godot_v${VERSION}-stable_linux.x86_64.zip"
BIN_NAME="Godot_v${VERSION}-stable_linux.x86_64"
# SHA512 publicado en la release oficial (SHA512-SUMS.txt de 4.7.2-stable)
SHA512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable/${ZIP}"
DIR="${GODOT_DIR:-/opt/godot/${VERSION}}"
BIN="${DIR}/${BIN_NAME}"

if [ -x "$BIN" ] && "$BIN" --headless --version 2>/dev/null | grep -q "^${VERSION}\.stable"; then
	echo "Godot ${VERSION} ya instalado: $BIN" >&2
else
	echo "Instalando Godot ${VERSION} en $DIR" >&2
	mkdir -p "$DIR"
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	curl -sSL --fail --retry 3 -o "$TMP/$ZIP" "$URL"
	echo "${SHA512}  $TMP/$ZIP" | sha512sum -c --quiet -
	unzip -o -q "$TMP/$ZIP" -d "$DIR"
	chmod +x "$BIN"
	"$BIN" --headless --version 2>/dev/null | grep -q "^${VERSION}\.stable" || {
		echo "Godot descargado pero no arranca: $BIN" >&2
		exit 1
	}
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export GODOT=\"$BIN\"" >>"$CLAUDE_ENV_FILE"
fi

# capture.sh necesita pantalla: en la nube no hay, se lanza con xvfb-run
if ! command -v xvfb-run >/dev/null 2>&1; then
	echo "AVISO: falta xvfb-run; tools/capture.sh no podrá hacer capturas en esta máquina" >&2
fi
