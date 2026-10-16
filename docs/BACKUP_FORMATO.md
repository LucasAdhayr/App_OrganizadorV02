# Formato do arquivo de backup (v1)

JSON em UTF-8, com recuo de 2 espaços. Pensado para ser lido por um HTML/planilha depois.

```json
{
  "format": "organizador-backup",
  "version": 1,
  "createdAt": "2026-10-14T23:00:00.000",
  "counts": { "tasks": 12, "history": 80, "notes": 5, "dates": 3, "entries": 40 },
  "settings": { "palette": "verde", "effects": "soft", "reviewAfterDays": "14", "waterGoal": "8" },
  "tasks":   [ { "id": "...", "title": "...", "kind": "single|recurring|reusable",
                 "status": "pending|snoozed|done|discarded",
                 "due": "2026-10-15", "time_minutes": 540,
                 "rec_type": "daily|weekdays|everyNDays|monthDay|yearly",
                 "rec_weekdays": "1,3", "rec_interval": 1, "rec_day": 1, "rec_month": 1,
                 "notes": "", "created_at": 1760000000000, "updated_at": 1760000000000,
                 "snoozed_until": null, "last_done_at": null } ],
  "history": [ { "id": "...", "at": 1760000000000, "kind": "done", "task_id": "...",
                 "task_title": "...", "detail": "" } ],
  "notes":   [ { "id": "...", "text": "...", "created_at": 1760000000000,
                 "is_idea": 0, "converted": 0, "deleted_at": null } ],
  "dates":   [ { "id": "...", "title": "Aniversário da Ana", "kind": "birthday|date",
                 "month": 3, "day": 8, "year": 1990, "notes": "", "created_at": 1760000000000 } ],
  "entries": [ { "id": "...", "module": "agua|alimentacao|exercicios|livros", "at": 1760000000000,
                 "data": { "...campos do módulo..." },
                 "created_at": 1760000000000, "updated_at": 1760000000000, "deleted_at": null } ]
}
```

- Datas sem hora (`due`) são `aaaa-mm-dd`. Instantes são milissegundos desde 1970 (fuso do aparelho ao exibir).
- `time_minutes` é o horário em minutos desde 00:00 (540 = 09:00).
- `rec_weekdays`: 1 = segunda ... 7 = domingo.
- Notas apagadas não entram no backup.
- `dates` (aniversários e datas anuais) foi acrescentada na Etapa 5; `year` pode ser `null`. Backups sem a chave `dates` continuam válidos (versão 1).
- Mudanças futuras no formato aumentam `version`; o app recusa arquivos de versão mais nova que a sua.

## Registros dos módulos (`entries`)
`data` é um objeto com os campos de cada módulo (no banco fica como texto JSON; no backup, como objeto):
- `agua`: `{}` (um registro = um copo; `at` é a hora).
- `alimentacao`: `{ "meal": "cafe|almoco|lanche|jantar|outro", "text": "..." }`.
- `exercicios`: `{ "kind": "Caminhada", "minutes": 40, "notes": "..." }` (`minutes` e `notes` opcionais).
- `livros`: `{ "title": "...", "author": "...", "total": 320, "page": 120, "status": "lendo|quero|lido" }` (`total` opcional).
A chave `entries` é opcional em backups antigos; `settings.waterGoal` é a meta diária de copos.
