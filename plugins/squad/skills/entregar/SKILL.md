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
| Fix rounds 1–2 | mesmo implementer (resume) | — |
| Verificação dos critérios: suíte, checks, browser ponta a ponta | `squad:QA` | (do papel: sonnet) |
| Task review (só quando obrigatório, ver abaixo) | `squad:Reviewer` | `sonnet` |
| Task review de task que toca zona de risco | `squad:Reviewer` | (do papel: opus) |
| Re-review de fix | `squad:Reviewer` | `sonnet` |
| Review final da branch | `squad:Reviewer` | (do papel: opus) |
| Fix round 3 (escalada) | `squad:Specialist` | (do papel: opus) |

**Task review só quando obrigatório:** a task toca zona de risco, ou o diff do commit dela passa
de ~150 linhas alteradas (`git show --stat`). As demais não têm task review: o review final
(`squad:Reviewer`, opus) lê o diff inteiro contra a spec e é o gate delas. Registre no
`entrega.md` quais tasks pularam o task review.

**Limite de fix rounds:** 2 no implementer; o 3º vai para o `squad:Specialist`. Se ainda não
passar, pare e leve ao usuário — três rodadas no mesmo ponto quase sempre indicam spec errada ou
ambígua, não código.

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
   - `## Task N: <nome>`: ACs cobertos, o teste que prova cada AC (arquivo e nome do caso a
     criar, ou "manual: <motivo>"), arquivos que a task possui (inclusive os de teste),
     dependências, zona de risco (sim/não), papel da tabela. ACs no mesmo componente ficam na mesma task; tasks paralelas
     nunca possuem o mesmo arquivo.
   - Mudou UI? Última task = verificação ponta a ponta pelo `squad:QA`.
   - `## Rulings`: decisões de orquestração tomadas sem o usuário, uma por linha, com o motivo.
   - `## Estado`: task → `pendente | em andamento | review | ok`, atualizado a cada passo.
   Resolva ambiguidades verificáveis (campo do DTO, formato de helper) no próprio plano antes do
   dispatch, via `squad:Analyst` se exigir descoberta.
7. **Executar.** Para cada task, na ordem das dependências:
   1. Dispatch ao papel da tabela com o bloco de dispatch do `squad:orquestrar` preenchido:
      objetivo, ACs com o teste de cada um ("teste primeiro, veja falhar, implemente"), arquivos
      que possui, Restrições globais, o que já foi descoberto (`path:linha`), branch, "rode só
      os testes que a task toca; a suíte completa é do QA", "commit ao terminar com Conventional Commits, só com a mensagem — sem trailer
      `Co-Authored-By` nem linha de atribuição", "não commitar fora dos arquivos da task".
   2. **Paralelo só com worktree.** Duas tasks escrevendo no mesmo working tree disputam o
      índice do git (`index.lock`, `git add` levando arquivo da outra) mesmo sem arquivo em
      comum. Uma task sozinha roda no working tree da branch. Tasks independentes lançadas juntas
      rodam cada uma com `isolation: "worktree"`, commitando no worktree dela; ao terminar, traga
      os commits para a branch da feature com `git cherry-pick <sha>` na ordem do plano. Conflito
      no cherry-pick → `git cherry-pick --abort` e fix round no implementer da task que chegou
      depois, já sobre a branch atualizada.
   3. Aja sobre a linha de handoff conforme `squad:orquestrar` (`escalate` sobe um degrau,
      `open decision` do usuário vai para o usuário, de orquestração vira ruling).
   4. Se a task exige task review (ver acima), rode no `squad:Reviewer` sobre o diff do commit
      dela. `ADJUST`/`OBJECT` → fix round no mesmo implementer (resume) com a lista do Reviewer,
      depois re-review, dentro do limite de fix rounds.
   5. Atualize `## Estado`.
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
    muda, a verificação (testes, checks, browser), as pendências estacionadas e os rulings, sem
    rodapé de atribuição. Referência à origem: `Closes #<n>` se a issue é do mesmo
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
| AC sem teste que o prove | Teste por AC no plano; o Reviewer bloqueia o que faltar |
| Implementer rodando a suíte completa a cada task | Testes focados na task; suíte completa só no QA |
| Orquestrador lendo o diff para conferir `done` | Confere o relatório; o diff é do Reviewer |
| Duas tasks paralelas no mesmo arquivo | Junte na mesma task ou sequencie |
| Tasks paralelas commitando no mesmo working tree | `isolation: "worktree"` por task + cherry-pick |
| Task review em toda task | Só zona de risco ou diff > ~150 linhas; o resto fica para o review final |
| `Co-Authored-By` ou rodapé de atribuição em commit/MR | Só a mensagem |
| Verificação de UI só por classe CSS no jsdom | Task de browser no QA |
| QA usando o banco de dev compartilhado | Banco isolado por feature |
| QA corrigindo o bug que achou | Ele só reporta; o fix volta ao implementer |
| Assumption não confirmada bloqueando a execução | Ruling no `entrega.md` e seguir |
| Perguntar merge/PR/manter no fim | Sempre push + MR/PR |
| `glab` num remote do GitHub (ou vice-versa) | CLI conforme `git remote get-url origin` |
| Fix de uma linha no Developer, re-review pequeno em opus | `squad:Executor` no fix, `squad:Reviewer` com `model: sonnet` no re-review |
