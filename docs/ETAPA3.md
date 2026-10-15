# Etapa 3: notificações, diagnóstico e histórico editável

## Lembretes
Regras (em `lib/core/reminders.dart`, função pura e testada):
- Tarefa com horário: avisa na hora marcada.
- Tarefa só com data: avisa na véspera e no dia, às 09:00.
- Tarefa adiada: vale o horário do adiamento.
- Recorrente: só a ocorrência atual; ao concluir ou pular, o plano é refeito.
- Sem data (reutilizável) e tarefas concluídas/descartadas: nada.
- Silêncio: nada toca entre 00:00 e 05:00; quem cairia aí vai para as 05:00.
- Até 50 lembretes agendados por vez (os mais próximos).
- Passado nunca dispara. Atrasadas não geram aviso repetido.

Como funciona: toda mudança em tarefa chama `AppState.replan()`, que troca TODOS os lembretes agendados (`Notifier.replace`). Mudanças seguidas viram uma troca só. São alarmes do sistema (`flutter_local_notifications`), então valem com o app fechado e voltam após reiniciar o celular (receiver de boot no manifest). Horários exatos usam permissão de alarme exato; sem ela, o aviso pode atrasar alguns minutos.

## Diagnóstico
Configurações > Diagnóstico de notificações: mostra permissão, alarmes exatos, quantos lembretes estão agendados e os próximos; botões para pedir permissões, reagendar tudo e testar (agora e em 1 minuto). Inclui o passo a passo para Xiaomi/Poco (início automático, bateria sem restrições, cadeado nos recentes).

## Histórico editável
Tocar num registro: abrir a tarefa, mudar data/hora do registro, ou apagar só o registro (a tarefa não muda). As duas ações têm DESFAZER.

## Mudanças de projeto
- Novas dependências: `flutter_local_notifications ^19.4.0`, `timezone ^0.10.0`.
- Android: permissões e receivers no `AndroidManifest.xml`; `coreLibraryDesugaring` no `build.gradle.kts`.

## Como validar
```
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```
No celular:
1. Diagnóstico > "Notificação agora": deve aparecer.
2. "Notificação em 1 minuto", feche o app por completo (remova dos recentes) e espere. Se não chegar, siga o passo a passo na própria tela.
3. Crie uma tarefa para daqui a 3 minutos, com horário, e feche o app: deve avisar.
4. Crie uma tarefa só com data de amanhã: no Diagnóstico, "Próximos lembretes" mostra amanhã 09:00.

O primeiro build após esta etapa pode demorar, pois o Gradle baixa dependências novas.
