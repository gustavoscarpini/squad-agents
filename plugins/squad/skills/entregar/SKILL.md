---
name: entregar
description: Entrega uma spec de ponta a ponta com a squad — da spec ao MR/PR. Use quando o usuário passar uma spec ou issue para implementar, "soltar o desenvolvimento", "entregar a issue/spec" — seja um caminho em `.specs/`, um slug de feature, ou uma issue de GitLab, GitHub ou outro tracker (inclusive de outro repositório).
argument-hint: <.specs/features/slug | slug | URL ou número da issue>
---

# Entregar spec com a squad

Leva uma spec até um MR/PR aberto, despachando para os papéis da squad (`squad:<Papel>`) conforme
`squad:orquestrar`, com Opus só onde o julgamento paga o custo. A spec mora em
`.specs/features/<slug>/` no repositório do código, versionada; o tracker é só uma das origens.

Entrada: $ARGUMENTS

## Papéis (passe `subagent_type` explicitamente em TODO dispatch)

O modelo vem do papel. Só passe `model` onde a tabela manda rebaixar.

| Trabalho | `subagent_type` | `model` |
|----------|-----------------|---------|
| Implementer a partir de spec em prosa / vários arquivos | `squad:Developer` | (do papel: sonnet) |
| Implementer de task numa zona de risco (encaixe/overlap, financeiro, migration, auth, concorrência) **sem padrão existente no repo** | `squad:Specialist` | (do papel: opus) |
| Implementer quando a spec já traz o código completo; fix de um arquivo só já decidido | `squad:Executor` | (do papel: haiku) |
| Escrita externa já decidida (comentário na issue, label, arquivo de verificação) | `squad:Executor` | (do papel: haiku) |
| Fix rounds 1–3 | mesmo implementer (resume) | — |
| Verificação dos critérios: suíte, checks, browser ponta a ponta | `squad:QA` | (do papel: sonnet) |
| Task review | `squad:Reviewer` | `sonnet` |
| Task review de task que toca zona de risco | `squad:Reviewer` | (do papel: opus) |
| Re-review de fix | `squad:Reviewer` | `sonnet` |
| Review final da branch | `squad:Reviewer` | (do papel: opus) |
| Fix rounds 4–5 (escalada) | `squad:Specialist` | (do papel: opus) |

**Uma task de código só:** pule o task review e vá direto ao review final (`squad:Reviewer`,
opus) sobre a branch; ele é o gate dessa task. Registre o ruling.

**Contexto do orquestrador:** comandos estreitos (`grep -n` num arquivo, `head`, `sed -n`), nunca
varrer `generated/`, `target/`, `node_modules/` ou dumps grandes; descoberta ampla vai para o
`squad:Analyst`.

## Passos

1. **Resolver a origem.**
   - Caminho para `.specs/features/<slug>/` (ou um arquivo dentro) ou só o `<slug>` → spec local.
   - Issue do GitLab (`…/-/issues/<n>`, `…/-/work_items/<n>`, `#<n>`) → `glab issue view <n>`, com
     `-R <grupo/projeto>` quando a issue é de outro projeto.
   - Issue do GitHub (`github.com/…/issues/<n>`) → `gh issue view <n> -R <dono/repo>`.
   - Outro tracker (Jira, Linear, …) → a ferramenta MCP conectada; sem nenhuma, peça ao usuário
     para colar o conteúdo. Nunca adivinhe o corpo.
   - Se o corpo da issue aponta uma spec (`Spec: <caminho ou URL>`), leia essa spec — ela vence o
     corpo. Se aponta para outro repositório, leia de lá sem clonar o repo inteiro (`glab api` /
     `gh api` / raw).
   - Guarde a referência da origem (`grupo/projeto#n`, URL) para o fechamento.
2. **Trazer a spec para o repo.** Se a spec ainda não existe em `.specs/features/<slug>/` neste
   repositório, crie `spec.md` lá com o conteúdo da origem e uma linha `Origem: <ref>` no topo. O
   slug sai do título (kebab-case, sem acento); sem contexto para nomear, pergunte. Esse arquivo é
   o primeiro commit da branch (`docs: spec <slug>`).
3. **Reconhecer o formato.**
   - `plan.md` + `checks.md` (tlc-spec-lean): os critérios EARS são os ACs; os checks são o que o
     QA prova.
   - `spec.md` / `design.md` / `tasks.md` (tlc-spec-driven): use as tasks de `tasks.md` como
     estão; `design.md` vira restrição.
   - Arquivo único ou corpo de issue: extraia os ACs; se não houver critério verificável, pare e
     diga o que falta — não invente critérios.
   - Assumptions marcadas como não confirmadas: o pedido de entregar conta como aprovação dos
     defaults; registre como ruling.
4. **Regras do repo.** Leia `AGENTS.md`/`CLAUDE.md` e a memória do projeto (runtime, banco,
   portas, regra de comentários, idioma, comando de teste/build). Viram Restrições globais.
5. **Branch.** Se estiver em `main`/`master`/detached, crie `<tipo>/<slug>` conforme o repo
   antes de qualquer commit. Se a branch já existe, continue nela e leia o `entrega.md` existente
   (passo 6) para retomar de onde parou.
6. **Plano de execução.** Escreva `.specs/features/<slug>/entrega.md` com:
   - `## Restrições globais`: arquivos permitidos, textos exatos, proibições do repo, comandos de
     teste/build/lint.
   - `## Task N: <nome>`: ACs cobertos, arquivos que a task possui, dependências, zona de risco
     (sim/não), papel da tabela. ACs no mesmo componente ficam na mesma task; tasks paralelas
     nunca possuem o mesmo arquivo.
   - Mudou UI? Última task = verificação ponta a ponta pelo `squad:QA`.
   - `## Rulings`: decisões de orquestração tomadas sem o usuário, uma por linha, com o motivo.
   - `## Estado`: task → `pendente | em andamento | review | ok`, atualizado a cada passo.
   Resolva ambiguidades verificáveis (campo do DTO, formato de helper) no próprio plano antes do
   dispatch, via `squad:Analyst` se exigir descoberta.
7. **Executar.** Para cada task, na ordem das dependências (independentes em paralelo, num lote
   só):
   1. Dispatch ao papel da tabela com: objetivo, ACs, arquivos que possui, Restrições globais,
      branch, "commit ao terminar com Conventional Commits e o trailer de atribuição da sessão",
      "não commitar fora dos arquivos da task".
   2. Aja sobre a linha de handoff conforme `squad:orquestrar` (`escalate` sobe um degrau,
      `open decision` do usuário vai para o usuário, de orquestração vira ruling).
   3. Task review no `squad:Reviewer` sobre o diff do commit da task. `ADJUST`/`OBJECT` → fix
      round no mesmo implementer (resume) com a lista do Reviewer, depois re-review. Rounds 4–5
      vão para o `squad:Specialist`. Depois do 5º, pare e leve ao usuário.
   4. Atualize `## Estado`.
8. **Verificar.** `squad:QA` sobre a branch inteira: suíte completa, os checks de `checks.md`
   quando existirem, e o browser se mudou UI (Playwright no scratchpad, banco isolado
   `<db>_<slug>`). `FAIL` → fix round no implementer da task dona do arquivo, depois QA de novo só
   sobre o que falhou. Quando o formato tem `verification.md`, o relatório do QA é gravado lá via
   `squad:Executor`.
9. **Review final.** `squad:Reviewer` (opus) sobre `git diff <base>...HEAD` contra a spec.
   `ADJUST`/`OBJECT` → fix round e novo review final, uma vez.
10. **Fechar com MR/PR.** Suíte verde e QA `PASS`: commit do `entrega.md`, `git push -u origin
    <branch>` e abra pelo CLI do remote — `glab mr create --target-branch <default>` no GitLab,
    `gh pr create --base <default>` no GitHub. Título Conventional Commits; descrição com o que
    muda, a verificação (testes, checks, browser), as pendências estacionadas, os rulings e o
    rodapé de atribuição da sessão. Referência à origem: `Closes #<n>` se a issue é do mesmo
    projeto, `Closes <grupo/projeto>#<n>` se de outro projeto no mesmo GitLab, ou só o link
    quando é de outro tracker — e então comente o link do MR/PR na issue via `squad:Executor`.
    Nunca merge local nem push na branch padrão. Termine com o link do MR/PR e a lista de rulings.

## Erros comuns

| Erro | Correção |
|------|----------|
| Dispatch sem `subagent_type` | Cai no general-purpose com o modelo da sessão; sempre `squad:<Papel>` |
| `model: opus` num papel que já é opus, ou `sonnet` esquecido no task review comum | Siga a coluna `model` da tabela |
| Implementar direto do corpo da issue sem trazer para `.specs/` | Passo 2 sempre; a spec fica versionada com o código |
| Inventar ACs quando a spec não tem critério verificável | Pare e diga o que falta |
| Duas tasks paralelas no mesmo arquivo | Junte na mesma task ou sequencie |
| Verificação de UI só por classe CSS no jsdom | Task de browser no QA |
| QA usando o banco de dev compartilhado | Banco isolado por feature |
| QA corrigindo o bug que achou | Ele só reporta; o fix volta ao implementer |
| Assumption não confirmada bloqueando a execução | Ruling no `entrega.md` e seguir |
| Perguntar merge/PR/manter no fim | Sempre push + MR/PR |
| `glab` num remote do GitHub (ou vice-versa) | CLI conforme `git remote get-url origin` |
| Fix de uma linha no Developer, re-review pequeno em opus | `squad:Executor` no fix, `squad:Reviewer` com `model: sonnet` no re-review |
