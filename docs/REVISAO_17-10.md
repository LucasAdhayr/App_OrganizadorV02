# Revisão de 17/10 — alarmes, código, efeitos

## Alarmes: o que estava errado (e já foi corrigido)
1. **Números dos avisos repetidos (causa mais provável das falhas).** A função que gera o número de cada aviso tinha um erro (`h ^= c` duas vezes se anulava), então tarefas e remédios com ids do mesmo tamanho recebiam o MESMO número no Android, e um aviso apagava o outro. Corrigido (FNV-1a de verdade) e adicionada uma garantia final: se dois avisos ainda colidirem, o número é deslocado. Testes novos cobrem isso.
2. **Recorrentes só avisavam a ocorrência atual.** Uma rotina diária com alarme tocava uma vez e depois ficava muda até você abrir o app e concluir. Agora as ocorrências dos próximos 7 dias também ficam agendadas.
3. **Reagendamento derrubava alarmes.** A cada minuto o app cancelava TODOS os avisos e agendava de novo. Isso podia parar um alarme que estivesse tocando e deixava janelas sem aviso. Agora: só reenvia se o plano mudou, e remove apenas o que sobrou (nada de "cancelar tudo"). Ao voltar para o app, confere com o que o sistema realmente tem.
4. **Falha em um aviso travava os outros.** Agora cada um é agendado separadamente, com plano B (modo aproximado) se o exato for negado.
5. **Alarmes cortados pelo limite.** Alarmes (remédios e tarefas com alarme) têm limite próprio (150) e nunca são cortados por lembretes comuns (80).
6. **Janela dos remédios** aumentada de 7 para 14 dias à frente (cobre viagem/semana sem abrir o app).
7. **Diagnóstico** ganhou: situação da economia de bateria, atalhos para tirar a restrição, para o som/volume do canal "Alarmes" e para as configurações do app.

## Limite que o app não consegue contornar
Em Xiaomi/Poco, deslizar o app para fora dos recentes pode "forçar parada" e o sistema apaga os alarmes. Faça: Início automático ligado, bateria "Sem restrições" e cadeado no card do app (atalhos no Diagnóstico). Sem isso, qualquer app de alarme falha nesse celular.

## Outras correções
- Backup automático não rodava se só havia remédios/água/datas (considerava só tarefas e notas). Corrigido.
- Telas vazias centralizadas em todo o app (Entrada, Tarefas, Histórico, além de Agenda/Hoje/Datas).
- Configurações: removido texto repetido e desatualizado ("Chegam na Etapa 3", "Etapa 4").

## Efeitos e cores
- Novo efeito **GRANULADO** (COMPLETO + textura de filme). Fixo: nada pisca nem se move, não gasta bateria.
- Novas paletas **ROSA** e **GELO** (teste automático garante contraste legível em todas as cinco).

## Não verificado (não há como compilar aqui)
Tudo precisa de `flutter analyze` / `flutter test` / teste no celular. Pontos de maior risco: `lib/services/notifier.dart` (opções do plugin de notificações) e o código Kotlin novo em `MainActivity.kt` (atalhos de configuração).
