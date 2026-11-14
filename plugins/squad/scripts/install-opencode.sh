#!/usr/bin/env bash
#
# Liga os perfis gerados em opencode/agents/ ao diretório global de agentes do
# OpenCode via symlink, para que `scripts/build.py` atualize os dois de uma vez.
# Não sobrescreve arquivo existente que não seja um symlink. Com --force,
# reaponta symlinks que hoje apontam para outro checkout/worktree do repo.
#
#   bash scripts/install-opencode.sh            # instala
#   bash scripts/install-opencode.sh --remove   # remove só os symlinks deste repo
#   bash scripts/install-opencode.sh --force    # reaponta symlinks de outro checkout

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "${HERE}/../opencode/agents" && pwd)"
DEST="${OPENCODE_AGENTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/agents}"

remove=false
force=false
for arg in "$@"; do
  case "${arg}" in
    --remove) remove=true ;;
    --force) force=true ;;
    *) echo "opção desconhecida: ${arg}" >&2; exit 2 ;;
  esac
done

mkdir -p "${DEST}"
for f in "${SRC}"/*.md; do
  target="${DEST}/$(basename "${f}")"
  if [ "${remove}" = true ]; then
    if [ -L "${target}" ] && [ "$(readlink "${target}")" = "${f}" ]; then
      rm "${target}" && echo "removido ${target}"
    fi
    continue
  fi
  if [ -L "${target}" ] && [ "$(readlink "${target}")" = "${f}" ]; then
    echo "ok ${target}"
  elif [ -L "${target}" ] && [ "${force}" = true ]; then
    ln -sfn "${f}" "${target}" && echo "reapontado ${target}"
  elif [ -e "${target}" ] || [ -L "${target}" ]; then
    echo "PULADO ${target}: já existe e não é deste repo (use --force para reapontar symlink)" >&2
  else
    ln -s "${f}" "${target}" && echo "ligado ${target}"
  fi
done
