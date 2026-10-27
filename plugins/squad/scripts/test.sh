#!/usr/bin/env bash
#
# Confere que os gerados estão em dia com src/, que os nomes dos papéis batem
# entre roles.json, agents/, opencode/agents/ e a tabela da skill, e que os
# manifests são coerentes. Nunca toca ~/.config/opencode nem ~/.claude.
#
#   bash scripts/test.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "${HERE}/.." && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"

fail() { echo "FAIL: $1" >&2; exit 1; }

python3 "${HERE}/build.py" --check || fail "gerados desatualizados"
echo "PASS: gerados em dia com src/"

python3 - "${PLUGIN}" "${REPO_ROOT}" <<'PY' || fail "checagem de nomes/manifests falhou"
import json, pathlib, re, sys

plugin, root = (pathlib.Path(a) for a in sys.argv[1:3])
roles = set(json.loads((plugin / "src/roles.json").read_text()))

def fm(path):
    m = re.match(r"^---\n(.*?)\n---\n", path.read_text(), re.S)
    if not m:
        sys.exit(f"{path}: sem frontmatter")
    return dict(l.split(": ", 1) for l in m.group(1).splitlines() if ": " in l and not l.startswith(" "))

claude = {fm(p)["name"] for p in (plugin / "agents").glob("*.md")}
opencode = {p.stem for p in (plugin / "opencode/agents").glob("*.md")} - {"lead"}
src_bodies = {p.stem for p in (plugin / "src/roles").glob("*.md")}

skill = (plugin / "skills/orquestrar/SKILL.md").read_text()
section = skill.split("## Pedido → agente", 1)[1].split("\n## ", 1)[0]
table = [c.strip() for line in section.splitlines()
         if line.startswith("|") and not line.startswith("|---") and not line.startswith("| Pedido")
         for c in [line.strip("|").split("|")[-1]]]
if len(table) != len(set(table)):
    sys.exit(f"agente duplicado na tabela da skill: {table}")

lower = {r.lower() for r in roles}
if not (roles == claude == set(table)) or not (lower == opencode == src_bodies):
    sys.exit(
        "conjuntos de papéis divergem:\n"
        f"  roles.json: {sorted(roles)}\n  agents/: {sorted(claude)}\n"
        f"  tabela da skill: {sorted(table)}\n  opencode/agents/: {sorted(opencode)}\n"
        f"  src/roles/: {sorted(src_bodies)}"
    )

for p in (plugin / "opencode/agents").glob("*.md"):
    mode = fm(p).get("mode")
    expected = "primary" if p.stem == "lead" else "subagent"
    if mode != expected:
        sys.exit(f"{p}: mode {mode!r}, esperado {expected!r}")

mp = json.loads((root / ".claude-plugin/marketplace.json").read_text())
manifest = json.loads((plugin / ".claude-plugin/plugin.json").read_text())
entry = {p["name"]: p for p in mp["plugins"]}.get(manifest["name"])
if not entry:
    sys.exit(f"plugin {manifest['name']!r} ausente do marketplace")
if (root / entry["source"]).resolve() != plugin:
    sys.exit(f"source do marketplace {entry['source']!r} não aponta para {plugin}")
if mp["metadata"]["version"] != manifest["version"]:
    sys.exit(f"versão diverge: marketplace={mp['metadata']['version']} plugin={manifest['version']}")
PY
echo "PASS: papéis e manifests"

bash -n "${HERE}/test.sh" "${HERE}/install-opencode.sh" || fail "bash -n"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${HERE}/test.sh" "${HERE}/install-opencode.sh" || fail "shellcheck"
fi
echo "ALL PASS"
