# ETAPA 1: ROTEIRO DE TESTE NO CELULAR

O código desta etapa foi escrito sem poder compilar. Pode haver erros de compilação; mande a mensagem completa e corrigimos.

## Rodar

```
cd C:\dev\App_OrganizadorV02
git pull
flutter pub get
flutter analyze
flutter test
flutter run -d 6ccee07c
```

- `flutter analyze` mostra erros e avisos do código. Me mande a saída se aparecer algo.
- `flutter test` roda os testes de regras. Todos devem passar.

## O que olhar

**Visual**
- [ ] Fundo preto e texto verde fósforo, fonte monoespaçada, acentos corretos (ç, ã, é).
- [ ] Em CONFIGURAÇÕES: trocar tema (VERDE, ÂMBAR, CIANO) e efeitos (OFF, SUAVE, COMPLETO). Os efeitos atrapalham a leitura em algum nível?
- [ ] Nada pisca nem se move sozinho.

**Navegação**
- [ ] Barra de baixo: HOJE, AGENDA, `+`, ENTRADA, MÓDULOS. O item selecionado fica invertido.
- [ ] Topo: histórico à esquerda, engrenagem à direita.

**Tarefas (tela HOJE)**
- [ ] Seções AGORA, HOJE e EM BREVE, com no máximo 7 itens e "Ver mais".
- [ ] Tocar em `[ ]` conclui. Aparece "DESFAZER" por alguns segundos.
- [ ] Deslizar para a direita conclui; para a esquerda abre as opções de adiar.
- [ ] Tocar no texto abre os detalhes (concluir, adiar, pular, editar, descartar).
- [ ] Atrasadas mostram `[!]` e "!ATRASADA nD" (sinal além da cor).

**Criar e editar**
- [ ] `+` > TAREFA: criar uma recorrente (dias da semana), uma única com prazo e uma reutilizável.
- [ ] Criar uma tarefa e editá-la pelos detalhes.
- [ ] `+` > Nota ou ideia; depois, em ENTRADA, abrir a nota e usar "Virar tarefa".

**Outras telas**
- [ ] REVISÃO: abre pelo botão no topo de HOJE (aparece com tarefas antigas de exemplo).
- [ ] MÓDULOS > TAREFAS: recorrentes, únicas e reutilizáveis ("feito há X dias" e "Preciso de novo").
- [ ] HISTÓRICO: filtros por período e ação; tocar em um registro abre a tarefa.

## Limitações conhecidas

- Dados só em memória; fecham com o app.
- O seletor de data do Android pode começar a semana no domingo. Ajustamos depois, se incomodar.
- Módulos além de TAREFAS e ENTRADA aparecem como "EM BREVE".
