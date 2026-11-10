#!/usr/bin/env bash
#
# Dispara um papel da squad como worker supervisionado do Orca, no agente e
# modelo da rota "orca" do papel em src/roles.json (ex.: OpenCode + DeepSeek).
# O spec do worker é o corpo do papel (opencode/agents/<papel>.md) seguido do
# prompt de delegação, porque o worker sobe no agente padrão do CLI e não no
# perfil da squad.
#
#   bash scripts/orca-dispatch.sh <Papel> <prompt.md> [--title <texto>] [--worktree <seletor>] [-- <args extras do worker-start>]
#
# Saída 0: worker iniciado (o recibo do Orca vai para stdout).
# Saída 3: sem rota utilizável (fora do Orca, papel sem rota, CLI ou modelo
#          indisponível) — use o subagente nativo.
# Outra:   falha do worker-start; não rode de novo, leia o recibo.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "${HERE}/.." && pwd)"

skip() { echo "SEM ROTA ORCA: $1 — use o subagente nativo" >&2; exit 3; }

[ $# -ge 2 ] || { echo "uso: $0 <Papel> <prompt.md> [--title <texto>] [--worktree <seletor>] [-- <args>]" >&2; exit 2; }
role="$1"; prompt="$2"; shift 2
title=""
worktree="current"
while [ $# -gt 0 ]; do
  case "$1" in
    --title) title="$2"; shift 2 ;;
    --worktree) worktree="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
[ -f "${prompt}" ] || { echo "prompt não encontrado: ${prompt}" >&2; exit 2; }

route="$(python3 - "${PLUGIN}/src/roles.json" "${role}" <<'PY'
import json, sys
roles = json.load(open(sys.argv[1]))
match = {k.lower(): v for k, v in roles.items()}.get(sys.argv[2].lower(), {})
orca = match.get("orca") or {}
if orca.get("agent") and orca.get("model"):
    print(orca["agent"], orca["model"])
PY
)"
[ -n "${route}" ] || skip "papel ${role} sem rota orca em roles.json"
read -r agent model <<<"${route}"

ORCA="${ORCA_CLI_COMMAND:-}"
[ -n "${ORCA}" ] || skip "sessão fora do Orca (ORCA_CLI_COMMAND ausente)"
command -v "${ORCA%% *}" >/dev/null 2>&1 || skip "CLI do Orca não encontrado: ${ORCA}"

if [ "${agent}" = "opencode" ]; then
  command -v opencode >/dev/null 2>&1 || skip "opencode não está no PATH"
  # `opencode models` lista no stderr; captura antes do grep para não cair em SIGPIPE com pipefail
  models="$(opencode models 2>&1 || true)"
  grep -qxF "${model}" <<<"${models}" || skip "modelo ${model} indisponível no opencode"
fi

body="${PLUGIN}/opencode/agents/$(echo "${role}" | tr '[:upper:]' '[:lower:]').md"
[ -f "${body}" ] || skip "corpo do papel não encontrado: ${body}"

spec="$(mktemp "${TMPDIR:-/tmp}/squad-orca-XXXXXX")"
{
  # corpo do papel sem frontmatter e sem o cabeçalho de gerado
  awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "${body}" | grep -v '^<!-- Gerado'
  printf '\n---\n\n# Delegação\n\n'
  cat "${prompt}"
  printf '\n\n---\n\nAo terminar, o corpo do worker_done é o relatório completo do papel, no formato da seção Relatório acima, sem resumir: abra com `RESULT:` (QA) ou `VERDICT:` (Reviewer) quando o papel exigir, e termine na linha de handoff.\n'
} >"${spec}"

echo "worker: ${role} → ${agent} ${model} | HEAD antes: $(git rev-parse --short HEAD 2>/dev/null || echo '-')" >&2
echo "git status antes:" >&2
git status --porcelain 2>/dev/null | sed 's/^/  /' >&2 || true

# shellcheck disable=SC2086  # ORCA pode ser "caminho args"
exec ${ORCA} orchestration worker-start \
  --worktree "${worktree}" \
  --agent "${agent}" --model "${model}" \
  --task-title "${title:-${role}}" \
  --spec-file "${spec}" \
  ${@+"$@"}
