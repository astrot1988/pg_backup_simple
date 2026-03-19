# pg_backup_simple

Простой Docker-контейнер для SQL backup PostgreSQL с cron-расписанием и компактным retention-конфигом.

Репозиторий: [github.com/astrot1988/pg_backup_simple](https://github.com/astrot1988/pg_backup_simple)

Контейнер: [ghcr.io/astrot1988/pg_backup_simple](https://github.com/astrot1988/pg_backup_simple/pkgs/container/pg_backup_simple)

## Что умеет

- По расписанию запускает `pg_dump`
- Сохраняет backup в `*.sql.gz`
- Поддерживает retention через `KEEP_HOURLY`, `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `KEEP_YEARLY`
- Если `KEEP_*` не заданы, ничего не удаляет
- Конфигурируется через один `.env`

## Быстрый старт

```bash
cp .env.example .env
docker compose up -d --build
```

## GitHub Container Registry

После пуша в `main` GitHub Actions собирает и публикует образ в GHCR.

Пример использования:

```bash
docker pull ghcr.io/astrot1988/pg_backup_simple:latest
```

## Основные настройки

- `DATABASE_URL` - самый короткий способ задать подключение
- `CRON` - cron-выражение, например `0 2 * * *`
- `BACKUP_DIR` - путь внутри контейнера
- Папка на хосте фиксирована: `./backups`
- `KEEP_HOURLY`, `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `KEEP_YEARLY` - сколько периодов хранить

## Как работает retention

- Для каждого периода сохраняется последний backup в этом периоде
- Backup сохраняется, если он попал хотя бы под одно правило retention
- Пустое значение `KEEP_*` означает "не ограничивать этот тип retention"
- Если все `KEEP_*` пустые, сохраняются все backup-файлы

Пример:

- `KEEP_HOURLY=24` - оставить последние 24 часа
- `KEEP_DAILY=7` - оставить последние 7 дней
- `KEEP_WEEKLY=8` - дополнительно оставить последние 8 недель
- `KEEP_MONTHLY=12` - дополнительно оставить последние 12 месяцев

## Ручной запуск backup

```bash
docker compose exec pg-backup /app/backup.sh
```

## Тестовый стенд

Есть отдельный `compose` с stub-базой PostgreSQL и тестовым backup-контейнером.

Запуск:

```bash
docker compose -f docker-compose.test.yml up -d --build
```

Что поднимается:

- `postgres` c тестовой БД `app`
- `pg-backup` с подключением к этой БД
- backup каждые 5 минут
- файлы backup сохраняются в `./test_backups`

Инициализация базы лежит в [testdb/init.sql](/Users/aleksejlutovinov/Projects/quank-mvp/pg_backup_simple/testdb/init.sql).

Для ручного теста backup:

```bash
docker compose -f docker-compose.test.yml exec pg-backup /app/backup.sh
ls -la ./test_backups
```

## Тест retention

Есть shell-тест для [retention.sh](/Users/aleksejlutovinov/Projects/quank-mvp/pg_backup_simple/retention.sh), который проверяет:

- отключенный retention
- `KEEP_HOURLY`
- `KEEP_DAILY`
- `KEEP_WEEKLY`
- `KEEP_MONTHLY`
- `KEEP_YEARLY`
- совместную работу нескольких правил

Запуск:

```bash
docker build -t pg_backup_simple:test .
docker run --rm -v "$PWD":/app -w /app --entrypoint bash pg_backup_simple:test tests/retention_test.sh
```
