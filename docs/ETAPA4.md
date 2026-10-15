# Etapa 4: backup e restauração

## Onde ficam os arquivos
`Downloads/Organizador/` no celular, via MediaStore (não pede permissão de armazenamento). Nome: `organizador-backup-AAAA-MM-DD-HHMMSS-<tipo>.json`, com tipo `manual`, `auto` ou `antes-de-restaurar`. Para sincronizar com o Drive, aponte o app de sincronização para essa pasta (o app não envia nada pela internet).

Limite do Android: o app só enxerga os arquivos que ele mesmo criou. Depois de reinstalar, a lista "Salvos pelo app" vem vazia; use "Escolher um arquivo..." e selecione o .json.

## Backup
- Manual: Configurações > Backup e restauração > "Fazer backup agora".
- Automático (23:00, pode desligar): o app não roda em segundo plano. Se estiver aberto às 23:00, faz na hora; se estiver fechado, faz na próxima abertura (ou ao voltar para o app). Não faz backup com o app vazio. Se falhar, mostra o erro e tenta de novo em 30 min. Guarda os 14 últimos automáticos; manuais e cópias de segurança nunca são apagados.
- A tela mostra a data e o tipo do último backup (também em Configurações).

## Restauração
1. Escolher um arquivo (seletor do sistema) ou tocar em um da lista.
2. O app valida o arquivo inteiro (formato, versão, cada registro) antes de mexer em qualquer coisa.
3. Confirmação mostrando data e quantidades.
4. Grava uma cópia dos dados atuais (`...-antes-de-restaurar.json`). Se isso falhar, a restauração é cancelada.
5. Troca tarefas, histórico, notas e tema numa transação do banco (tudo ou nada) e reagenda os lembretes.

Formato do arquivo: `docs/BACKUP_FORMATO.md`.

## Novo no projeto
- Código nativo: `MainActivity.kt` (canal `br.pessoal.organizador/backup`: salvar, listar, ler, apagar em Downloads/Organizador e escolher arquivo pelo seletor do sistema; sem plugin extra). Exige Android 10+ (seu Poco tem 12).

## Como validar
```
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```
No celular:
1. Configurações > Backup e restauração > "Fazer backup agora". Abra o app Arquivos > Downloads > Organizador: o .json deve estar lá.
2. Mude algo (apague uma tarefa, crie outra). Toque no backup na lista e restaure: deve voltar ao estado do backup, e uma cópia "antes-de-restaurar" deve aparecer na pasta.
3. Escolher um arquivo...: selecione o .json pelo seletor.
4. Automático: com o relógio passando das 23:00 e o app aberto, deve aparecer um arquivo `-auto`.
