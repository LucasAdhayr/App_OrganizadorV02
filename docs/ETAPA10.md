# Etapa 10 — MNEMO (marca, calendários, anotações, doses)

## Remédios: doses e alarme insistente
- Cada horário de remédio vira uma **dose**. Passou o horário e ninguém marcou = dose pendente.
- Em HOJE e em MEDICAMENTOS aparece **REMÉDIO: HORA DE TOMAR** com `Tomei` e `Não tomei`.
- O alarme toca no horário e **repete de 10 em 10 minutos até a meia-noite** do mesmo dia, ou até você marcar a dose (o plano é refeito na hora).
- Passou a meia-noite sem marcar: a dose vai para **REMÉDIO: MARCAR O QUE PASSOU** (últimos 7 dias), para marcar depois (`Tomei` ou `Não tomei`). Ambos têm desfazer.
- Limite técnico: no máximo 120 toques repetidos agendados de uma vez (hoje e amanhã, os mais próximos primeiro); o plano se renova ao abrir o app ou marcar uma dose.
- Dados: entradas `doses` (`med`, `key`, `status` = taken/skipped).

## Calendários (quadradinhos)
- EXERCÍCIOS, ALIMENTAÇÃO e ANIVERSÁRIOS têm LISTA | CALENDÁRIO.
- Visões MÊS (com número do dia) e ANO (12 meses pequenos; tocar no nome do mês abre o mês). Setas mudam mês/ano. Semana começa na segunda.
- Quadrado cheio = tem registro; vazio = nada; moldura grossa = hoje (nunca só por cor).
- Tocar no dia abre a ficha com o que foi feito, e dá para abrir/editar cada item.
- ANIVERSÁRIOS abre direto no calendário do ano atual, com as datas marcadas.

## Livros: anotações
- Dentro de um livro: botão **Anotações** (texto, página opcional, data). Entradas `anotacoes_livro` (`book`, `text`, `page`).
- A lista de livros mostra quantas anotações cada um tem.

## MNEMO
- Nome do app: MNEMO (Μνημοσύνη, Mnemosine). Nomes internos (pacote, banco, backup) não mudaram, para não quebrar backups.
- Ícone novo: Μ em blocos dentro da esfera wireframe, moldura CRT e friso grego (adaptativo + monocromático). Abertura escura com a marca.
- Friso grego (meandro) sob o título de cada tela; Μ dentro da esfera nas telas vazias; epígrafe em HOJE.
- 3 paletas: VIOLETA, PERGAMINHO, VERMELHO (total 8).
- 2 efeitos: FITA (faixas e riscos de videocassete) e ANTIGO (papel envelhecido). Tudo fixo, nada pisca.
