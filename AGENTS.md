# AGENTS.md

- Docker image factory, not a Laravel app. Build sources: `Dockerfile3.20`, `Dockerfile3.23`, `Dockerfile3.24`.
- `base/` is copied into images; `HAS_NGINX` selects `base/nginx` vs `base/core` supervisor config.
- `8.3/` and `8.4/` are sample `docker-compose.yaml` / `kube-pod.yaml` / `test.json` fixtures, not image code. `tests/Unit` is empty; no PHP/Composer test suite.
- Docs are stale (`README.md`, `SECURITY.md`): they list old PHP versions. Trust `.github/workflows/*` for the active matrix and published tags.

## Build / verify

- `make build` (default goal) builds only 8.3+8.4/alpine3.20, 8.5/alpine3.23, 8.5+8.6/alpine3.24. One variant: `make build-tag-mysql-nginx/3.24/8.6`; target patterns are `build-tag-mysql`, `build-tag-mysql-nginx`, `build-tag-pgsql`, `build-tag-pgsql-nginx` with `<alpine>/<php>`.
- Makefile local tags are `<php>-<variant>-alpine<alpine>` and never pass `BUILD_XDEBUG` or `PHP_FULL_VERSION`. CI/release tags are `<php>-alpine<alpine>-<variant>[-xdebug][-amd64|-arm64]`. Do not treat Makefile output as a release tag.
- Build args: `PHP_VERSION`, `DATABASE_MODULE=mysqli|pgsql`, `HAS_NGINX=0|1`, `BUILD_XDEBUG=0|1`, plus Buildx-provided `TARGETOS`/`TARGETARCH`. `Dockerfile3.23` and `Dockerfile3.24` also use `PHP_FULL_VERSION` for `FROM php:...` (defaults to `PHP_VERSION`).
- CI image check is `tests/ci/image-smoke-test.sh`; older 3.16 workflow used `php -m` and is removed. CI then makes multi-arch manifests with `docker buildx imagetools create` for `ghcr.io/eightsystems/laravel-alpine` and `8sistemas/laravel-alpine`; Xdebug variants are CI-only.
- Workflows trigger on master pushes matching listed `8.x/**`, Dockerfile, and workflow paths, plus the 1st/15th schedule. New PHP versions need matrix + path-filter updates or push won't trigger. `[skipci]`/`[noci]` skip only `build-images`; `link-container-tags` still runs.

## Runtime / image quirks

- Entrypoint always runs `tini -- php /usr/local/bin/run-with-secrets.php` before CMD. It expands JSON/INI from `EXPAND_SECRETS_FROM_VARIABLE` / `EXPAND_SECRETS_FROM_FILE` (comma-separated, optional `:json`/`:ini`) and writes values via `EXPAND_SECRETS_WRITE_TO_FILE` (`VAR=/path:base64|text`). `DEBUG_SECRETS=1` enables debug output. Default CMD is Go supervisord, config `/etc/supervisord.conf`.
- Exporters only start when `ENABLE_PROMETHEUS_EXPORTER_RUNNER=1`: PHP-FPM `:9090`, nginx stub `:8081`, nginx exporter `:9190`, nginx app `:8080`, supervisorctl `127.0.0.1:9999`.
- Cron uses `sudo` to run `crond` as root and defaults to `/var/www/artisan schedule:run` every minute; keep `setuid`/`setgid` caps or delete `/etc/supervisor.d/01_crond.ini`. Read-only containers need tmpfs at `/tmp`, `/run/nginx`, `/var/lib/nginx/tmp`.
- Packages do not all come from the base Alpine repo: Dockerfile3.20 pulls nginx from `v3.23/main` (its own repo is unpatched); Dockerfile3.23 uses native nginx from `v3.23`; Dockerfile3.24 uses native nginx from `v3.24`. PHP 8.5+ strips `zend_extension=opcache.so` because opcache is built in.
- All Dockerfiles use Go 1.27 + supervisord commit `3a1bade`, patched at build to stop overriding PATH when a program sets `user=`. Without the patch, non-root PATH omits `/usr/local/sbin` and `php-fpm` is not found.
