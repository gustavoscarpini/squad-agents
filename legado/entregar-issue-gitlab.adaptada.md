---
name: entregar-issue-gitlab
description: Use when the user passes a GitLab issue or work item (URL or número) and asks to implement it, "soltar o desenvolvimento", or "entregar a issue" with subagents.
argument-hint: <url ou número da issue do GitLab>
---

# Entregar issue do GitLab com subagents

Transforma uma issue do GitLab num plano SDD e executa com **superpowers:subagent-driven-development**, despachando para os papéis da squad (`squad:<Papel>`, plugin `squad`, skill `squad:orquestrar`), com Opus só onde o julgamento paga o custo.

## Papéis (passe `subagent_type` explicitamente em TODO dispatch)

O modelo vem do papel. Só passe `model` onde a tabela manda rebaixar.

| Trabalho | `subagent_type` | `model` |
|----------|-----------------|---------|
| Implementer a partir de spec em prosa / vários arquivos | `squad:Developer` | (do papel: sonnet) |
| Implementer de task numa zona de risco (encaixe/overlap, financeiro, migration, auth, concorrência) **sem padrão existente no repo** | `squad:Staff` | (do papel: opus) |
| Implementer quando o plano já traz o código completo; fix de um arquivo só já decidido | `squad:Junior` | (do papel: haiku) |
| Fix rounds 1–3 | mesmo implementer (resume) | — |
| Verificação no browser / suíte ponta a ponta | `squad:QA` | (do papel: sonnet) |
| Task review | `squad:TechLead` | `sonnet` |
| Task review de task que toca zona de risco | `squad:TechLead` | (do papel: opus) |
| Re-review de fix | `squad:TechLead` | `sonnet` |
| Review final da branch | `squad:TechLead` | (do papel: opus) |
| Fix rounds 4–5 (escalada) | `squad:Staff` | (do papel: opus) |

**Prompt e retorno.** Use os templates de prompt do SDD como corpo do dispatch; o papel acrescenta o contrato da squad e fecha com a linha dele, que é a que vale:

- implementers: `done` = DONE (com ressalvas no relatório = DONE_WITH_CONCERNS); `open decision` = NEEDS_CONTEXT — resolva com `Ruling:` no ledger se for decisão de orquestração, leve ao usuário se for dele; `escalate to <papel>` = BLOCKED — suba um degrau (Junior → Developer → Staff), nunca repita no mesmo papel; `not done` = BLOCKED com o motivo.
- `squad:TechLead`: `VERDICT: SOUND` = aprovado; `ADJUST`/`OBJECT` = issues para o fix round; `ESCALATE` = pergunta ao usuário, não vira ruling.
- `squad:QA`: `RESULT: PASS` segue; `FAIL` vira fix round com os passos de reprodução; `BLOCKED` resolva o ambiente ou leve ao usuário — nunca conta como verde.

**Uma task de código só:** se o plano tem uma única task que gera diff (a de browser não conta), pule o task review e vá direto ao review final (`squad:TechLead`, opus) sobre a branch; ele é o gate dessa task. Registre `Ruling: task review dispensado — branch de task única, review final cobre o mesmo diff` no ledger.

**Contexto do controller:** comandos estreitos (`grep -n` num arquivo, `head`, `sed -n`), nunca varrer `generated/` ou dumps grandes; tudo que entra no contexto é relido a cada turno.

## Passos

1. **Ler a issue.** Extraia o número de `…/-/work_items/<n>` ou `…/-/issues/<n>` e rode `glab issue view <n>` (com `-R <grupo/projeto>` se fora do repo). Se o corpo cita um spec (`Spec: <path>`), leia o arquivo; senão o corpo é o spec.
2. **Regras do repo.** Leia `AGENTS.md`/`CLAUDE.md` e a memória do projeto (versão de Node, banco, portas, regra de comentários, idioma). Elas viram Global Constraints.
3. **Branch.** Se estiver em `main`/`master`/detached, crie `<tipo>/<slug>` conforme o repo antes de qualquer commit; sem contexto para nomear, pergunte. Se a branch já existe, continue nela.
4. **Spec sem gate.** Se o repo exige spec/plan e a issue não traz nenhum, pare e diga. Assumptions marcadas como não confirmadas: o pedido de implementar a issue conta como aprovação dos defaults; registre como `Ruling:` no ledger.
5. **Plano SDD.** Escreva `.superpowers/sdd-plan-<slug>.md` (git-ignored) com:
   - `## Global Constraints`: arquivos permitidos, textos exatos, proibições do repo, comando de Node/teste/build.
   - `## Task N: <nome>`: um heading por task (o script `task-brief` depende disso). ACs que vivem no mesmo componente ficam na mesma task; tasks paralelas no mesmo arquivo conflitam.
   - Mudou UI? Última task = verificação ponta a ponta no browser via `squad:QA` (Playwright instalado no scratchpad, banco isolado `<db>_<slug>`, sem commit; bug é reportado, não corrigido).
   - Resolva ambiguidades verificáveis (campo do DTO, formato de helper) no próprio plano antes do dispatch.
6. **Executar.** Invoque `superpowers:subagent-driven-development` com o plano e siga-o à risca (ledger, preflight, review por task, review final), aplicando a tabela de papéis. Inclua em cada dispatch de implementer: branch, trailer de commit da sessão, "spec não commitado → commit `docs:` primeiro", e "nunca commitar `.superpowers/`".
7. **Fechar sempre com MR.** Rode a suíte completa; verde, faça `git push -u origin <branch>` e `glab mr create --target-branch main` com título Conventional Commits e descrição com `Closes #<n>`, o que muda, a verificação (testes + browser), as pendências estacionadas e o rodapé de atribuição da sessão. Não apresente o menu de `superpowers:finishing-a-development-branch`: o usuário já escolheu MR. Nunca merge local nem push em `main`. Termine com o link do MR e a lista de rulings.

## Erros comuns

| Erro | Correção |
|------|----------|
| Dispatch sem `subagent_type` | Cai no general-purpose com o modelo da sessão; sempre `squad:<Papel>` |
| `model: opus` passado num papel que já é opus, ou `sonnet` esquecido no task review comum | Siga a coluna `model` da tabela |
| Plano sem `## Task N` | `task-brief` falha; use o heading exato |
| Verificação de UI só por classe CSS no jsdom | Task de browser no fim |
| Subagent usando o banco de dev compartilhado | Banco isolado por feature |
| Assumption não confirmada bloqueando a execução | Ruling no ledger e seguir |
| Perguntar merge/PR/manter no fim | Sempre push + MR |
| Task review e review final em opus sobre o mesmo diff | Task única → só o review final |
| Fix de uma linha no Developer, re-review pequeno em opus | `squad:Junior` no fix, `squad:TechLead` com `model: sonnet` no re-review |
| QA corrigindo o bug que achou | Ele só reporta; o fix volta ao implementer |
