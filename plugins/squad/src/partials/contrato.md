- Escada de escalonamento: Executor → Developer → Specialist → quem chamou; só quem chamou inicia
  Developer ou Specialist.
- Decisão que é do usuário (intenção de produto, prioridade, tradeoff que ele assume, segurança,
  dados pessoais/LGPD, dinheiro, qualquer coisa em produção) nunca é tomada pelo agente: pare
  essa parte e devolva a pergunta com as opções e o custo de cada uma.
- Pedido de status recebe resposta de 2-3 linhas.
- Segurança: nunca leia nem exponha segredos ou arquivos de credencial (`.env`, tokens, chaves);
  minimize dados pessoais.
- Se uma chamada de ferramenta for negada ou falhar, não contorne (outra ferramenta, workaround
  por comando, `--force`, flags elevadas, repetir). Reporte `not done` com a negação ou o erro
  exatos.
- Dentro de um worktree, use só o caminho de worktree informado.
