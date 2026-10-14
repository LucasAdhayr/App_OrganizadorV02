# Organizador

Aplicativo pessoal de organização e hábitos para Android, pensado para quem tem TDAH: registrar rápido, lembrar sozinho e retomar sem culpa. Funciona 100% offline.

As decisões do projeto estão em [`docs/DECISOES.md`](docs/DECISOES.md).

## Rodar

```
flutter pub get
flutter run -d <id-do-celular>
```

Para testes das regras (recorrência, concluir, adiar, revisão):

```
flutter test
```

## Estado atual

**Etapa 2: banco local.** Tarefas, histórico, notas e configurações ficam salvos em SQLite no próprio celular e voltam ao reabrir o app. Ainda não há notificações nem backup.

| Etapa | Conteúdo | Estado |
|---|---|---|
| 0 | Ambiente e chave de assinatura | feita |
| 1 | Protótipo navegável com o tema | feita |
| 2 | Banco local (sqflite), tarefas e recorrências | em validação |
| 3 | Notificações, diagnóstico, histórico editável | próxima |
| 4 | Backup e restauração em arquivo local | — |
| 5 | Notas, ideias, aniversários | — |

## Estrutura

```
lib/
  app/      estado, paleta e tema
  core/     modelos e regras de datas/recorrência
  modules/  registro de módulos (gera MÓDULOS e o menu "+")
  ui/       widgets em estilo terminal, telas e folhas
test/       testes das regras
docs/       decisões e guias
```

Um módulo novo se declara em `lib/modules/registry.dart`; as telas MÓDULOS e o menu `+` passam a mostrá-lo sem mexer no núcleo.

## Segurança

O arquivo da chave de assinatura (`.jks`) e a senha **nunca** entram neste repositório.
