# cloudcli

[CloudCLI](https://github.com/siteboon/claudecodeui) — веб-интерфейс Claude Code
на домашнем сервере: http://code.home.internal (только дом и roam).
Чат с сессиями, дерево файлов, git, терминал; работает с телефона.

Своего кода нет: [`Dockerfile`](Dockerfile) ставит из npm `@cloudcli-ai/cloudcli`
и `@anthropic-ai/claude-code` закреплённых версий. Upstream публикует только
шаблоны Docker Sandboxes (`sbx`), обычного образа у него нет.

    push в main ──► GitHub Actions ──► ghcr.io/kamabyte/cloudcli:sha-<коммит>, :latest
                                                 │
                    Dokploy, стек cloudcli ◄─────┘   compose.yml
                                                 │
                    http://code.home.internal    (Traefik, nas-admin-only@file)

Контракт приложений и общие шаги — `homelab/docs/adding-app.md`.

## Данные

| На хосте | В контейнере | Что |
|---|---|---|
| `/srv/cloudcli/home` | `/home/node` | `~/.claude` (вход, сессии, настройки, MCP), `~/.cloudcli/auth.db` (пароль интерфейса), `~/.gitconfig`, `~/.ssh` |
| `/srv/cloudcli/workspace` | `/workspace` | проекты; за пределы CloudCLI их не создаёт |

Владелец — `1000:1000` (lenar), процесс в контейнере — пользователь `node` с тем же uid.

## Безопасность

Это терминал с ИИ-агентом в браузере. Всё, что смонтировано, он может
прочитать, изменить и отправить наружу. Поэтому:

- домен закрыт `nas-admin-only@file` прямо в `compose.yml` — с первого деплоя;
- порт не публикуется, `docker.sock`, `/`, медиадиска в контейнере нет;
- нужен репозиторий — `git clone` в `/workspace`, а не bind mount живых путей сервера;
- ключ для GitHub — отдельный deploy key или fine-grained токен на нужные
  репозитории, не личный ключ с Мака;
- пароль интерфейса задаётся при первом входе — сразу после деплоя.

## Установка

1. **Репозиторий** `kamabyte/cloudcli` на GitHub, push в `main` — Actions
   соберёт образ. Пакет в GHCR приватный, Dokploy тянет его через Settings → Registry.
2. **Каталоги на сервере:**

       sudo install -d -o 1000 -g 1000 -m 700 /srv/cloudcli /srv/cloudcli/home /srv/cloudcli/workspace

3. **Dokploy:** проект `cloudcli`, окружение `production`, стек Compose
   `cloudcli` (appName `cloudcli`). Источник — Git: публичный
   `https://github.com/kamabyte/cloudcli.git`, ветка `main`, файл `./compose.yml`;
   доступ к GitHub не нужен. Вкладку Domains не заполнять — домен в метках.
   Deploy.
4. **Первый вход:** http://code.home.internal → сразу задать пароль: до этого
   учётную запись может занять любой, кто открыл страницу из дома или roam.
   Мастер первого входа спросит имя и почту для git (`git config --global`):
   `kamabyte` и `13827900+kamabyte@users.noreply.github.com`.
5. **Вход в Claude:** вкладка Shell →

       claude            # затем /login: открыть ссылку на Маке, вставить код обратно

   Учётные данные ложатся в `/srv/cloudcli/home/.claude` и переживают пересборку.
6. **Ключ для push:** во вкладке Shell

       ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub

   Публичный ключ — в Deploy keys (с правом записи) тех репозиториев, куда
   нужен push, а не в SSH-ключи аккаунта.
7. **homelab:** строка `code` в `services.toml`, плитка на главной, `portal/deploy.sh`.

## Проверка

    curl -sI http://code.home.internal/          # с Мака: 200; из сети родных — 403
    sudo docker ps --filter name=cloudcli        # на сервере: (healthy)

## Новая версия

Поднять `CLOUDCLI_VERSION` и/или `CLAUDE_CODE_VERSION` в `Dockerfile`, push в
`main`, дождаться сборки в Actions, в Dokploy — Redeploy: он заберёт из git
свежий `compose.yml` и скачает образ (`pull_policy: always`). Правка только
`compose.yml` — тоже push и Redeploy. Кнопка обновления в самом интерфейсе не
сработает: `/usr/local` в образе принадлежит root. Откат — `IMAGE_TAG=sha-<коммит>`
во вкладке Environment и Redeploy.
