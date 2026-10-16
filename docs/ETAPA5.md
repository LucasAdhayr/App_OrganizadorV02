# Etapa 5: notas, ideias e aniversários

## Notas (ENTRADA)
- Novo: **editar o texto** (com DESFAZER) e **buscar** nas notas.
- Continua: nota rápida pelo "+", marcar como ideia, virar tarefa, apagar com DESFAZER.

## Módulo IDEIAS
Lista só as notas marcadas como ideia (mesma tela da ENTRADA, filtrada, com busca). Não é um tipo novo: nota e ideia são o mesmo registro.

## Módulo ANIVERSÁRIOS (e datas)
- Cada item: nome, tipo (ANIVERSÁRIO ou DATA), dia e mês, ano opcional, notas.
- Repete todo ano. 29/02 cai em 28/02 nos anos sem 29.
- Com o ano guardado, mostra a idade ("faz 36 anos"; em datas, "6 anos").
- Lembretes: véspera e dia, às 09:00 (mesma regra de prazos só com data; silêncio 00:00–05:00). A próxima ocorrência é a única agendada; ao virar o dia o plano se refaz sozinho quando o app abre ou volta.
- Na tela HOJE aparece a seção **DATAS** com o que cai hoje ou nos próximos 3 dias.
- Criar: "+" > ANIVERSÁRIO OU DATA, ou MÓDULOS > ANIVERSÁRIOS > Nova data. Tocar em uma data: editar ou apagar (DESFAZER).

## Dados
- Banco passou para a versão 2 (tabela `dates`). A migração só acrescenta a tabela; nada do que existe é apagado.
- Backup e restauração incluem as datas. Backups antigos (sem `dates`) continuam abrindo. Formato: `docs/BACKUP_FORMATO.md`.

## Como validar
```
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```
No celular:
1. ENTRADA: abra uma nota > "Editar texto"; digite algo no campo de busca.
2. Marque uma nota como ideia e abra MÓDULOS > IDEIAS.
3. MÓDULOS > ANIVERSÁRIOS > Nova data: crie um aniversário para amanhã (com ano). Deve aparecer em HOJE > DATAS e, em Configurações > Diagnóstico, um lembrete para hoje 09:00 (se ainda for antes) ou amanhã 09:00.
4. Faça um backup, apague a data e restaure: ela deve voltar.
5. Seus dados atuais não devem sumir após atualizar (banco v1 > v2).
