#!/usr/bin/env bash
#
# Liga os perfis gerados em opencode/agents/ ao diretório global de agentes do
# OpenCode via symlink, para que `scripts/build.py` atualize os dois de uma vez.
# Não sobrescreve arquivo existente que não seja um symlink para este repo.
#
#   bash scripts/install-opencode.sh            # instala
#   bash scripts/install-opencode.sh --remove   # remove só os symlinks deste repo

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "${HERE}/../opencode/agents" && pwd)"
DEST="${OPENCODE_AGENTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents}"

mkdir -p "${DEST}"
for f in "${SRC}"/*.md; do
  target="${DEST}/$(basename "${f}")"
  if [ "${1:-}" = "--remove" ]; then
    if [ -L "${target}" ] && [ "$(readlink "${target}")" = "${f}" ]; then
      rm "${target}" && echo "removido ${target}"
    fi
    continue
  fi
  if [ -L "${target}" ] && [ "$(readlink "${target}")" = "${f}" ]; then
    echo "ok ${target}"
  elif [ -e "${target}" ] || [ -L "${target}" ]; then
    echo "PULADO ${target}: já existe e não é deste repo" >&2
  else
    ln -s "${f}" "${target}" && echo "ligado ${target}"
  fi
done
