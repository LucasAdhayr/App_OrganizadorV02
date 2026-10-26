# Etapa 9 — Aulas

## O que tem
- **Disciplina** com vários horários semanais (ex.: Máquinas de Fluxo: terça 07:00 e quinta 15:00, repete toda semana).
- **Notas P1 e P2** (só essas duas), média simples, e "precisa de X na P2 para média 6,0" (a média para passar é configurável por disciplina, padrão 6,0).
- **Faltas:** máximo permitido e quantas já deu. Mostra "3/10 · restam 7"; com 2 ou menos faltas sobrando (ou acima do limite) aparece `[!]`. Botões −1 e +1 falta (com desfazer).
- **Provas e trabalhos:** data, descrição, horário opcional e alarme opcional. São tarefas ligadas à disciplina: aparecem em HOJE e AGENDA, avisam na véspera e no dia às 09:00 (ou no horário) e são concluídas como qualquer tarefa.
- **Aviso de aula:** por disciplina — sem aviso, na hora, 15/30/60 min antes (padrão 30) — como notificação ou alarme. Agendado 14 dias à frente.

## Onde aparece
- Módulo **AULAS**: aulas de hoje, próximas provas e trabalhos (todas as disciplinas) e a lista de disciplinas com horários, notas e faltas.
- **HOJE:** seção "AULAS DE HOJE" (com alerta de faltas).
- Tocar numa disciplina abre a tela dela (notas, faltas, provas e trabalhos, editar, apagar).
- "+" > AULA: nova disciplina, ou prova/trabalho de uma disciplina.

## Técnico
- Disciplina = `Entry` do módulo `aulas`; prova/trabalho = `Task` do módulo `aulas` com `ref` = id da disciplina (banco v7, coluna `tasks.ref`).
- `lib/core/course.dart` (regras puras), `lib/ui/screens/classes_screen.dart`.
- Renomear a disciplina renomeia as provas ("Prova: Nome"). Apagar a disciplina descarta as provas pendentes (ficam no histórico).
