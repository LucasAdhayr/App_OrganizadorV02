# Etapa 6: módulos simples (água, alimentação, exercícios, livros)

## Base comum
Os quatro módulos guardam registros na mesma tabela `entries` (instante, módulo e campos em JSON), como previsto em DECISOES ("tabela genérica com campo JSON"). Um módulo novo desse tipo não precisa de tabela nova nem de mudança no backup. Banco v3 (migração só acrescenta a tabela). Apagar é remoção lógica. Tudo entra no backup (`entries`) e é restaurado.

O "+" ganhou ação direta: ÁGUA registra um copo na hora; REFEIÇÃO, EXERCÍCIO e LIVRO abrem uma folha. O que ainda não existe continua em EM BREVE.

## ÁGUA
Conta copos, não mililitros. `+1 copo` / `Tirar 1`, meta diária (padrão 8, de 1 a 30), barra de progresso e `[OK]` quando bate a meta, e os últimos 7 dias. O "+" > COPO DE ÁGUA registra com DESFAZER.

## ALIMENTAÇÃO
Bloco de notas do que comeu (sem calorias): tipo (café, almoço, lanche, jantar, outro; sugerido pela hora), texto livre e data/hora (pode corrigir para o passado). Lista por dia; tocar: editar ou apagar com DESFAZER.

## EXERCÍCIOS
Atividade (atalhos: Caminhada, Corrida, Musculação, Bicicleta, Alongamento, ou texto livre), minutos e notas opcionais, data/hora. Mostra o resumo da semana (a semana começa na segunda): treinos e minutos.

## LIVROS
Título, autor e total de páginas opcionais; status LENDO / QUERO LER / LIDO. "Atualizar página" mostra o progresso; chegar ao total marca como lido; "Marcar como lido" completa. Lista agrupada por status.

## Fora desta etapa (de propósito)
Esses módulos não geram lembretes. Medicamentos e finanças (contas a pagar), que dependem de lembretes, ficam para a Etapa 7.

## Como validar
```
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```
No celular:
1. "+" > COPO DE ÁGUA várias vezes; abra MÓDULOS > ÁGUA, tire um copo, mude a meta.
2. ALIMENTAÇÃO: anote uma refeição, edite, mude a hora para ontem, apague e desfaça.
3. EXERCÍCIOS: registre uma caminhada de 30 min; veja o resumo da semana.
4. LIVROS: cadastre um livro com 300 páginas, atualize a página para 150, depois para 300 (deve virar LIDO).
5. Backup > apague um registro > restaure: tudo deve voltar.
6. Atualizar o app não deve apagar tarefas, notas nem datas (banco v2 > v3).

## Correções pós-teste (16/10)

- **Água:** passo fixo de 200 ml; meta diária em litros (0,5–6 L, passo de 250 ml). Avisos: 6h "Beba seu primeiro gole d'água"; 12h (<30%), 18h (<70%) "Beba mais água"; 21h (<100%) "Ainda falta beber água". Recalculados a cada gole registrado.
- **Exercícios:** são rotinas (tarefas com `module = exercicios`) que se repetem (diário, semanal, a cada X dias, mensal), aparecem em HOJE/AGENDA com a etiqueta EXERCÍCIO e avisam 1 hora antes. Concluir registra um treino no módulo.
- **Visual:** telas vazias (Agenda, Hoje, Datas, módulos) usam um único widget centralizado, sem texto cortado.
- Banco migrou para a versão 4 (coluna `module` em tarefas).
