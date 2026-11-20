# AGENTS.md

- Docker image factory, not a Laravel app. Build sources: `Dockerfile3.16`, `Dockerfile3.20`, `Dockerfile3.23`.
- `base/` is copied into images; `HAS_NGINX` selects `base/nginx` vs `base/core` supervisor config.
- `7.4/`…`8.4/` are sample `docker-compose.yaml` / `kube-pod.yaml` / `test.json` fixtures, not image code. `tests/Unit` is empty; no PHP/Composer test suite.
- Docs are stale (`README.md`, `SECURITY.md`): they list old PHP versions. Trust `.github/workflows/*` for the active matrix and published tags.

## Build / verify

- `make build` (default goal) builds only 8.2/alpine3.16, 8.3+8.4/alpine3.20, 8.5/alpine3.23. One variant: `make build-tag-mysql-nginx/3.23/8.5`; target patterns are `build-tag-mysql`, `build-tag-mysql-nginx`, `build-tag-pgsql`, `build-tag-pgsql-nginx` with `<alpine>/<php>`.
- Makefile local tags are `<php>-<variant>-alpine<alpine>` and never pass `BUILD_XDEBUG` or `PHP_FULL_VERSION`. CI/release tags are `<php>-alpine<alpine>-<variant>[-xdebug][-amd64|-arm64]`. Do not treat Makefile output as a release tag.
- Build args: `PHP_VERSION`, `DATABASE_MODULE=mysqli|pgsql`, `HAS_NGINX=0|1`, `BUILD_XDEBUG=0|1`, plus Buildx-provided `TARGETOS`/`TARGETARCH`. `Dockerfile3.23` also uses `PHP_FULL_VERSION` for `FROM php:...` (defaults to `PHP_VERSION`).
- CI's only image check is `docker run --rm <image> php -m`. CI then makes multi-arch manifests with `docker buildx imagetools create` for `ghcr.io/eightsystems/laravel-alpine` and `8sistemas/laravel-alpine`; Xdebug variants are CI-only.
- Workflows trigger on master pushes matching listed `8.x/**`, Dockerfile, and workflow paths, plus the 1st/15th schedule. New PHP versions need matrix + path-filter updates or push won't trigger. `[skipci]`/`[noci]` skip only `build-images`; `link-container-tags` still runs.

## Runtime / image quirks

- Entrypoint always runs `tini -- php /usr/local/bin/run-with-secrets.php` before CMD. It expands JSON/INI from `EXPAND_SECRETS_FROM_VARIABLE` / `EXPAND_SECRETS_FROM_FILE` (comma-separated, optional `:json`/`:ini`) and writes values via `EXPAND_SECRETS_WRITE_TO_FILE` (`VAR=/path:base64|text`). `DEBUG_SECRETS=1` enables debug output. Default CMD is Go supervisord, config `/etc/supervisord.conf`.
- Exporters only start when `ENABLE_PROMETHEUS_EXPORTER_RUNNER=1`: PHP-FPM `:9090`, nginx stub `:8081`, nginx exporter `:9190`, nginx app `:8080`, supervisorctl `127.0.0.1:9999`.
- Cron uses `sudo` to run `crond` as root and defaults to `/var/www/artisan schedule:run` every minute; keep `setuid`/`setgid` caps or delete `/etc/supervisor.d/01_crond.ini`. Read-only containers need tmpfs at `/tmp`, `/run/nginx`, `/var/lib/nginx/tmp`.
- Packages do not all come from the base Alpine repo: Dockerfile3.16/3.20 pull nginx from `v3.23/main` (their own repos are unpatched); Dockerfile3.23 uses native nginx from `v3.23`. Imagemagick in Dockerfile3.16 comes from `v3.23/community`. PHP 8.5 strips `zend_extension=opcache.so` because opcache is built in.
- All Dockerfiles use Go 1.27 + supervisord commit `3a1bade` (3.16 was updated from Go 1.18 + `c2cae38` to clear 106 Go CVEs).
