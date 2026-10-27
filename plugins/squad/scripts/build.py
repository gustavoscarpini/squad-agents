#!/usr/bin/env python3
"""Gera os agentes do Claude Code e do OpenCode a partir de src/.

    python3 scripts/build.py          # escreve os arquivos gerados
    python3 scripts/build.py --check  # falha se algum gerado estiver desatualizado

Fonte única: src/roles.json (metadados por papel), src/roles/<papel>.md (corpo),
src/partials/*.md (trechos de contrato compartilhados, inseridos via {{nome}}) e
src/orquestrar.md (manual do orquestrador). Blocos <!-- claude --> e
<!-- opencode --> só entram na saída do host correspondente.
"""

import json
import pathlib
import re
import sys

PLUGIN = pathlib.Path(__file__).resolve().parent.parent
SRC = PLUGIN / "src"
HOSTS = ("claude", "opencode")
HEADER = "<!-- Gerado por scripts/build.py a partir de src/. Não edite à mão. -->"

SKILL_DESCRIPTION = (
    "Manual de delegação para os seis agentes da squad (Executor, Analyst, Developer, "
    "Specialist, Reviewer, QA). Use para qualquer busca, mudança, edição em lote, "
    "pesquisa, review, verificação ou escrita externa (MCP/API/glab) que traria material bruto "
    "para o contexto principal — inclusive checar se algo existe ou como funciona, mesmo que "
    "seja um grep só. Não é para conversa simples, para ler um alvo já conhecido cujo conteúdo "
    "é a própria resposta, nem para uma edição de uma linha já decidida."
)
ORCHESTRATOR_DESCRIPTION = (
    "Orquestrador da squad: decide, sequencia, conversa com o usuário e delega para "
    "executor, analyst, developer, specialist, reviewer e qa."
)


def q(value):
    """Escalar YAML seguro (string JSON é YAML válido)."""
    return json.dumps(value, ensure_ascii=False)


def select_host(text, host):
    for other in HOSTS:
        pattern = rf"<!-- {other} -->\n(.*?)<!-- /{other} -->\n"
        text = re.sub(pattern, (r"\1" if other == host else ""), text, flags=re.S)
    return text


def render(text, host, partials):
    text = select_host(text, host)

    def sub(m):
        name = m.group(1)
        if name not in partials:
            sys.exit(f"partial desconhecido: {{{{{name}}}}}")
        return partials[name].rstrip("\n")

    text = re.sub(r"\{\{(\w+)\}\}", sub, text)
    if "{{" in text or "<!--" in text.replace(HEADER, ""):
        sys.exit("placeholder ou bloco de host não resolvido")
    return text.rstrip("\n") + "\n"


def frontmatter(fields):
    lines = ["---"]
    for key, value in fields.items():
        if isinstance(value, dict):
            lines.append(f"{key}:")
            lines.extend(f"  {k}: {q(v)}" for k, v in value.items())
        else:
            lines.append(f"{key}: {value if key in ('name', 'model', 'effort', 'mode') else q(value)}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def outputs():
    roles = json.loads((SRC / "roles.json").read_text())
    partials = {p.stem: p.read_text() for p in (SRC / "partials").glob("*.md")}
    out = {}

    for name, meta in roles.items():
        body = (SRC / "roles" / f"{name.lower()}.md").read_text()

        claude = {"name": name, "description": meta["description"], **meta["claude"]}
        out[f"agents/{name.lower()}.md"] = (
            frontmatter(claude) + HEADER + "\n\n" + render(body, "claude", partials)
        )

        oc = {"description": meta["description"], "mode": "subagent", "model": meta["opencode"]["model"]}
        if meta["opencode"].get("permission"):
            oc["permission"] = meta["opencode"]["permission"]
        out[f"opencode/agents/{name.lower()}.md"] = (
            frontmatter(oc) + HEADER + "\n\n" + render(body, "opencode", partials)
        )

    manual = (SRC / "orquestrar.md").read_text()
    out["skills/orquestrar/SKILL.md"] = (
        frontmatter({"name": "orquestrar", "description": SKILL_DESCRIPTION})
        + HEADER + "\n\n" + render(manual, "claude", partials)
    )
    out["opencode/agents/lead.md"] = (
        frontmatter({"description": ORCHESTRATOR_DESCRIPTION, "mode": "primary"})
        + HEADER + "\n\n" + render(manual, "opencode", partials)
    )
    return out


def main():
    check = "--check" in sys.argv[1:]
    stale = []
    for rel, content in outputs().items():
        path = PLUGIN / rel
        if check:
            if not path.exists() or path.read_text() != content:
                stale.append(rel)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
            print(f"gerado {rel}")
    if stale:
        sys.exit("desatualizado (rode scripts/build.py): " + ", ".join(stale))


if __name__ == "__main__":
    main()
