# Etapa 2: banco local, tarefas e recorrência

## O que mudou
- Dados salvos em SQLite no celular (`organizador.db`, armazenamento privado do app), 100% offline.
- Cada alteração é gravada na hora; ao abrir o app, `AppState.load()` traz tudo de volta.
- Camadas: `AppState` (regras) → `AppStore` (interface) → `SqliteStore` (SQL). `codec.dart` converte objetos em linhas e é testado sem banco.
- IDs são UUID v4. Enums são gravados pelo nome. Prazo como `aaaa-mm-dd`; instantes em milissegundos.
- Notas apagadas ficam no banco com `deleted_at` (remoção lógica). Tarefas nunca são apagadas: descartar é um estado.
- Se o banco falhar, o app abre mesmo assim e mostra um aviso `[!]` no topo.
- Configurações > "Carregar dados de exemplo": só funciona com o app vazio.

## Decisão: sqflite em vez de Drift/Riverpod
O plano falava em Drift. Troquei por `sqflite` com SQL escrito à mão: não exige geração de código (`build_runner`), o que reduz o risco de erro de ambiente para quem está começando, e o esquema é pequeno. A interface `AppStore` permite trocar depois sem mexer nas telas. O estado continua em `ChangeNotifier` (sem Riverpod).

## Correções desta etapa
- Tarefa recorrente só pode ser concluída ou pulada a partir do dia da ocorrência (`AppState.canComplete`). Antes dava para concluir sem parar e ela andava para a frente. A tela mostra "Ainda não. A próxima é ...".
- Datas de outro ano agora mostram o ano (`05/02/2027`).
- O aviso DESFAZER some sozinho em 3 segundos.

## Como validar
```
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```
Teste de persistência: crie uma tarefa, feche o app por completo (deslize para removê-lo dos recentes), abra de novo: ela deve continuar lá. O celular só precisa estar conectado durante o `flutter run`.

## Adiado (ver BACKLOG.md)
Mudanças no adiamento (amanhã no horário da tarefa, escolher data mais à frente).
