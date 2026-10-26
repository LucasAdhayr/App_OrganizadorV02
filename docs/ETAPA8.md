# Etapa 8 — Finanças

(Escopo decidido sem consulta, conforme autonomia dada: contas a pagar com vencimento + gastos.)

## Contas a pagar
- São tarefas do módulo `financas` com **valor** (centavos). Por isso aparecem em HOJE e AGENDA, avisam na véspera e no dia às 09:00 (ou no horário, se tiver) e podem ter **alarme**.
- **Única** (vence uma vez) ou **se repete** (todo mês no dia X, a cada N dias etc.).
- Tocar em "PAGAR" (ou deslizar) marca como paga: registra o pagamento nos lançamentos do mês e, se repete, já mostra a próxima. Dá para **pagar adiantado** (diferente das tarefas comuns); a próxima conta avança a partir do vencimento, não repete no mesmo mês.
- Desfazer remove o pagamento e devolve a conta.

## Gastos
- "Gasto": valor, descrição opcional, categoria (Mercado, Transporte, Casa, Saúde, Lazer, Outros) e quando.
- Tela FINANÇAS: total gasto no mês, quanto falta pagar até o fim do mês, contas a pagar, total por categoria, lançamentos do mês (editar/apagar) e os 3 últimos meses com movimento.

## Técnico
- Banco v6 (`tasks.amount_cents`). Gastos e pagamentos são `Entry` do módulo `financas`.
- Dinheiro sempre em centavos inteiros (`lib/core/money.dart`).
