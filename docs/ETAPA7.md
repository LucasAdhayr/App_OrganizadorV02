# Etapa 7 — Medicamentos e alarmes

## Alarmes
- **Todo remédio toca alarme** em todos os horários, sempre.
- **Tarefas e rotinas de exercício** têm o botão **Alarme** (Sem alarme / Tocar alarme) no formulário, visível quando há horário. Em exercícios, o alarme toca 1 hora antes, como o aviso.
- Como é o alarme: canal próprio "Alarmes" (som e volume de *alarme* do celular, passa pelo Não perturbar dos alarmes), tela acende sobre o bloqueio, som repetido até você tocar ou deslizar a notificação (no máximo 5 min), agendado como despertador do sistema (ícone de alarme na barra) quando "alarmes exatos" está liberado.
- Continua valendo o silêncio de 00:00 às 05:00: um alarme nessa janela vai para as 05:00.
- Os alarmes de remédio ficam agendados 7 dias à frente e **não entram no limite** de lembretes. O plano é refeito a cada abertura do app e a cada mudança.
- Diagnóstico tem o botão "Alarme em 1 minuto" para testar com o app fechado.

## Medicamentos
- Cadastro: nome, horários (um ou mais), unidades por vez, estoque atual.
- O estoque **desce sozinho** a cada horário que passa (sem confirmar cada dose).
- Mostra "dura até DD/MM (N dias)". Com 7 dias ou menos (ou acabou), aparece um aviso escrito em HOJE.
- Botões: **Adicionar estoque** (soma ao que resta), **Corrigir contagem**, **Parei de tomar** (desliga alarmes e congela o estoque; volta com "Voltar a tomar"), Editar, Apagar.
- Mudar horário/dose não refaz o consumo passado.

## Técnico
- Banco v5 (`tasks.alarm`). Remédios são `Entry` do módulo `medicamentos` (sem tabela nova).
- `lib/core/medication.dart` (regras de estoque), `lib/ui/screens/medication_screen.dart`, planejador em `lib/core/reminders.dart`, canal de alarme em `lib/services/notifier.dart`.
- Manifest: `USE_FULL_SCREEN_INTENT`, `WAKE_LOCK`, e a activity com `showWhenLocked`/`turnScreenOn`.
