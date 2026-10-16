# CloudCLI (siteboon/claudecodeui) — веб-интерфейс Claude Code: чат, файлы,
# git, терминал. Своего кода здесь нет: образ ставит пакеты из npm с
# закреплёнными версиями. Upstream публикует только шаблоны Docker Sandboxes
# (sbx, microVM), обычного образа у него нет.
#
# Новая версия — правка ARG ниже, push в main, Redeploy в Dokploy.

ARG NODE_IMAGE=node:22-bookworm-slim

# --- Сборка: нативные модули (node-pty, better-sqlite3, bcrypt) -------------
FROM ${NODE_IMAGE} AS build
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential python3 \
 && rm -rf /var/lib/apt/lists/*

ARG CLOUDCLI_VERSION=1.37.4
ARG CLAUDE_CODE_VERSION=2.1.301
RUN npm install -g --no-audit --no-fund \
      @cloudcli-ai/cloudcli@${CLOUDCLI_VERSION} \
      @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
 && cloudcli version \
 && claude --version

# --- Запуск ------------------------------------------------------------------
FROM ${NODE_IMAGE}
# git, ssh — работа с репозиториями; ripgrep — поиск Claude Code; tini —
# PID 1, собирает зомби от процессов терминала; curl — healthcheck.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client ripgrep jq less procps tini \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=build /usr/local/bin /usr/local/bin

# Пользователь node из базового образа — 1000:1000, как lenar на сервере:
# файлы в /srv/cloudcli принадлежат ему, sudo не нужен.
#
# /home/node — том: ~/.claude (сессии, вход, настройки, MCP), ~/.cloudcli
# (пароль интерфейса), ~/.gitconfig, ~/.ssh. /workspace — том с проектами;
# за его пределы CloudCLI проекты не создаёт (WORKSPACES_ROOT).
#
# Обновление из интерфейса (npm install -g) не сработает: /usr/local
# принадлежит root. Так и задумано — версии меняются только здесь.
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    SERVER_PORT=3001 \
    WORKSPACES_ROOT=/workspace \
    DATABASE_PATH=/home/node/.cloudcli/auth.db \
    DISABLE_AUTOUPDATER=1

USER node
WORKDIR /workspace
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3001/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["cloudcli", "start"]
