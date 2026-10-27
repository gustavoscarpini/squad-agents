---
name: entregar-issue-gitlab
description: Use when the user passes a GitLab issue or work item (URL or número) and asks to implement it, "soltar o desenvolvimento", or "entregar a issue" with subagents.
argument-hint: <url ou número da issue do GitLab>
---

# Entregar issue do GitLab com subagents

Transforma uma issue do GitLab num plano SDD e executa com **superpowers:subagent-driven-development**, com Opus só onde o julgamento paga o custo.

## Modelos (passe `model` explicitamente em TODO dispatch)

| Papel | Modelo |
|-------|--------|
| Implementer a partir de spec em prosa / vários arquivos | `sonnet` |
| Implementer quando o plano já traz o código completo; fix de um arquivo só | `haiku` |
| Fix rounds 1–3 | mesmo implementer (resume) |
| Verificação no browser | `sonnet` |
| Task review | `sonnet` |
| Task review de task que toca encaixe/overlap, financeiro, migration, auth ou concorrência | `opus` |
| Re-review de fix | `sonnet` |
| Review final da branch | `opus` |
| Fix rounds 4–5 (escalada) | `opus` |

**Uma task de código só:** se o plano tem uma única task que gera diff (a de browser não conta), pule o task review e vá direto ao review final em `opus` sobre a branch; ele é o gate dessa task. Registre `Ruling: task review dispensado — branch de task única, review final cobre o mesmo diff` no ledger.

**Contexto do controller:** comandos estreitos (`grep -n` num arquivo, `head`, `sed -n`), nunca varrer `generated/` ou dumps grandes; tudo que entra no contexto é relido a cada turno.

## Passos

1. **Ler a issue.** Extraia o número de `…/-/work_items/<n>` ou `…/-/issues/<n>` e rode `glab issue view <n>` (com `-R <grupo/projeto>` se fora do repo). Se o corpo cita um spec (`Spec: <path>`), leia o arquivo; senão o corpo é o spec.
2. **Regras do repo.** Leia `AGENTS.md`/`CLAUDE.md` e a memória do projeto (versão de Node, banco, portas, regra de comentários, idioma). Elas viram Global Constraints.
3. **Branch.** Se estiver em `main`/`master`/detached, crie `<tipo>/<slug>` conforme o repo antes de qualquer commit; sem contexto para nomear, pergunte. Se a branch já existe, continue nela.
4. **Spec sem gate.** Se o repo exige spec/plan e a issue não traz nenhum, pare e diga. Assumptions marcadas como não confirmadas: o pedido de implementar a issue conta como aprovação dos defaults; registre como `Ruling:` no ledger.
5. **Plano SDD.** Escreva `.superpowers/sdd-plan-<slug>.md` (git-ignored) com:
   - `## Global Constraints`: arquivos permitidos, textos exatos, proibições do repo, comando de Node/teste/build.
   - `## Task N: <nome>`: um heading por task (o script `task-brief` depende disso). ACs que vivem no mesmo componente ficam na mesma task; tasks paralelas no mesmo arquivo conflitam.
   - Mudou UI? Última task = verificação ponta a ponta no browser (Playwright instalado no scratchpad, banco isolado `<db>_<slug>`, sem commit; bug é reportado, não corrigido).
   - Resolva ambiguidades verificáveis (campo do DTO, formato de helper) no próprio plano antes do dispatch.
6. **Executar.** Invoque `superpowers:subagent-driven-development` com o plano e siga-o à risca (ledger, preflight, review por task, review final), aplicando a tabela de modelos. Inclua em cada dispatch de implementer: branch, trailer de commit da sessão, "spec não commitado → commit `docs:` primeiro", e "nunca commitar `.superpowers/`".
7. **Fechar sempre com MR.** Rode a suíte completa; verde, faça `git push -u origin <branch>` e `glab mr create --target-branch main` com título Conventional Commits e descrição com `Closes #<n>`, o que muda, a verificação (testes + browser), as pendências estacionadas e o rodapé de atribuição da sessão. Não apresente o menu de `superpowers:finishing-a-development-branch`: o usuário já escolheu MR. Nunca merge local nem push em `main`. Termine com o link do MR e a lista de rulings.

## Erros comuns

| Erro | Correção |
|------|----------|
| Dispatch sem `model` | Herda o modelo da sessão; sempre explícito |
| Plano sem `## Task N` | `task-brief` falha; use o heading exato |
| Verificação de UI só por classe CSS no jsdom | Task de browser no fim |
| Subagent usando o banco de dev compartilhado | Banco isolado por feature |
| Assumption não confirmada bloqueando a execução | Ruling no ledger e seguir |
| Perguntar merge/PR/manter no fim | Sempre push + MR |
| Task review e review final em `opus` sobre o mesmo diff | Task única → só o review final |
| Fix de uma linha em `sonnet`, re-review pequeno em `opus` | `haiku` no fix, `sonnet` no re-review |
