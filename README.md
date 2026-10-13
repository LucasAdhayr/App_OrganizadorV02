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

**Etapa 1: protótipo navegável.** Telas, tema e gestos funcionam, mas os dados são de exemplo e ficam só na memória (somem ao fechar o app). Ainda não há banco local, notificações nem backup.

| Etapa | Conteúdo | Estado |
|---|---|---|
| 0 | Ambiente e chave de assinatura | feita |
| 1 | Protótipo navegável com o tema | em validação |
| 2 | Banco local (Drift), tarefas e recorrências | próxima |
| 3 | Notificações, diagnóstico, histórico editável | — |
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
