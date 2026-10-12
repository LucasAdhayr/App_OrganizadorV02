# DECISÕES FECHADAS

Atualizado em 2026-10-12. Onde este documento diverge da especificação original, vale este.

## Plataforma
- Android, Poco X3 (MIUI, Android 12). APK para uso pessoal.
- Flutter + Drift (SQLite) + Riverpod.
- Computador de desenvolvimento: Windows, com Git, conta no GitHub e VS Code.
- Repositório: https://github.com/LucasAdhayr/App_OrganizadorV02.git

## Escopo: 100% offline
- Sem internet, sem Google Drive, sem login, sem IA, sem voz.
- Toda entrada é feita por formulários específicos de cada módulo.
- Backup é um arquivo JSON no próprio celular (pasta Download ou outra escolhida).
- Para usar no PC: copiar o arquivo de backup. Um HTML futuro lerá esse arquivo para gráficos e análises.
- Sem criptografia e sem biometria.

## Backup
- Manual (botão) e automático (diário, por volta das 23:00, via WorkManager).
- O app mostra sempre a data do último backup e o motivo de qualquer falha.
- Se o último backup tiver mais de 24 h, roda ao abrir o app.
- Restauração: sempre com confirmação e cópia de segurança prévia.
- JSON com `schemaVersion`, legível pelo HTML futuro.
- Risco aceito: backup só no celular não protege contra perda ou reset do aparelho. Copiar o arquivo para o PC de vez em quando.

## Navegação e tela inicial
- Barra inferior: `HOJE · AGENDA · [+] · ENTRADA · MÓDULOS`, com rótulo de texto em cada ícone.
- Topo: histórico à esquerda, engrenagem à direita.
- Hoje agregada em `AGORA`, `HOJE`, `EM BREVE`, no máximo 5 a 7 itens, com "ver mais".
- `+` abre a escolha do tipo de registro e depois o formulário do módulo.
- `ENTRADA` guarda notas rápidas, que podem virar tarefa ou ideia. Notas e ideias são o mesmo tipo.
- Linha da tarefa: só título e prazo/data.
- Gestos: toque no marcador ou deslizar à direita conclui; deslizar à esquerda adia; toque no texto abre detalhes; descartar fica dentro dos detalhes. Desfazer por alguns segundos.

## Tarefas
Três tipos:
1. **Recorrente:** data e horário fixos pelo calendário. Cada ocorrência tem estado próprio.
2. **Única:** com prazo ou sem. Concluiu, acabou.
3. **Reutilizável** (ex.: limpar o quarto): sem recorrência. Marca como feita, mostra "feito há X dias", "preciso de novo" reabre. Cada conclusão fica no histórico. Fica fora do Hoje enquanto concluída.

Frequências: diária, dias da semana, a cada N dias ou semanas, dia do mês, anual.
Ocorrências atrasadas: o Hoje mostra só a atual; as anteriores vão para a revisão.
Revisão de antigas: 14 dias sem atualização, máximo de 3 por vez.

## Notificações
- Silêncio: 00:00 às 05:00.
- Adiamentos: 10 min, 1 h, hoje à noite, amanhã.
- Tarefa só com data: aviso 1 dia antes e às 09:00 do dia. (Confirmar se o aviso da véspera também é às 09:00.)
- Tela de bloqueio: texto discreto por padrão, com opção de mostrar tudo.
- Tela de diagnóstico de lembretes (MIUI: início automático, bateria sem restrições, alarmes exatos).

## Dados
- Tabelas próprias: tarefas, ocorrências, conclusões, histórico.
- Módulos simples (notas, ideias, alimentação, livros, finanças no começo): tabela genérica com campo JSON.
- Todo registro tem UUID, criado/atualizado em e remoção lógica.
- Histórico guardado sem limite.
- Fuso do aparelho. Semana começa na segunda.

## Visual
- Verde fósforo sobre preto. Temas por variáveis (outros temas depois).
- Efeitos `Off / Suave / Completo`, padrão `Suave`. Nada piscando.
- Fonte monoespaçada limpa no corpo; pixel só em títulos, se suportar acentos.
- Maiúsculas só em títulos e rótulos.
- Informação nunca depende só de cor.
- Respeita o tamanho de fonte do sistema. Alvos de toque de pelo menos 48 px.

## Ordem de desenvolvimento
- **0** Ambiente e chave de assinatura
- **1** Protótipo navegável com o tema
- **2** Banco local, tarefas e recorrências, com testes
- **3** Notificações, diagnóstico e histórico editável
- **4** Backup e restauração locais
- **5** Notas, ideias, aniversários
- **6+** Demais módulos (alimentação como bloco de notas; medicamentos e outros depois)

Prioridade declarada: lembrar o que fazer, avisar sobre tarefas, guardar anotações sem perdê-las.
