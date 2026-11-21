#!/bin/sh
# Smoke tests for laravel-alpine images.
#
# Mounted into the container at runtime, so no image changes required:
#   docker run --rm \
#     -v "$PWD/tests/ci/image-smoke-test.sh:/smoke-test.sh:ro" \
#     -e PHP_VERSION=8.5 -e DATABASE_MODULE=mysqli \
#     -e HAS_NGINX=1 -e BUILD_XDEBUG=0 -e ALPINE_VERSION=3.23 \
#     --entrypoint sh <image> /smoke-test.sh
#
# Required env (defaults shown):
#   PHP_VERSION      - expected PHP major.minor, e.g. 8.5
#   DATABASE_MODULE  - mysqli (default) or pgsql
#   HAS_NGINX        - 1 or 0 (default 0)
#   BUILD_XDEBUG     - 1 or 0 (default 0)
#   ALPINE_VERSION   - informational only

set -eu

PHP_VERSION="${PHP_VERSION:-}"
DATABASE_MODULE="${DATABASE_MODULE:-mysqli}"
HAS_NGINX="${HAS_NGINX:-0}"
BUILD_XDEBUG="${BUILD_XDEBUG:-0}"
ALPINE_VERSION="${ALPINE_VERSION:-}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

echo "== image-smoke-test =="
echo "PHP=$PHP_VERSION DB=$DATABASE_MODULE nginx=$HAS_NGINX xdebug=$BUILD_XDEBUG alpine=$ALPINE_VERSION"

# ---------------------------------------------------------------------------
# PHP runtime and modules
# ---------------------------------------------------------------------------
command -v php >/dev/null 2>&1 || fail "php not found in PATH"
php -v >/dev/null 2>&1 || fail "php -v failed"

ACTUAL_PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
if [ -n "$PHP_VERSION" ] && [ "$ACTUAL_PHP_VERSION" != "$PHP_VERSION" ]; then
    fail "PHP version mismatch: expected $PHP_VERSION, got $ACTUAL_PHP_VERSION"
fi

MODULES="$(php -m | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')"

has_module() {
    case " $MODULES " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

require_modules() {
    for module in "$@"; do
        has_module "$module" || fail "PHP module missing: $module"
    done
}

forbid_modules() {
    for module in "$@"; do
        if has_module "$module"; then
            fail "PHP module unexpectedly present: $module"
        fi
    done
}

# Modules installed by every variant of the Dockerfiles.
require_modules \
    bcmath bz2 calendar core ctype curl date dom event exif fileinfo filter \
    gd gettext gmp hash iconv imagick intl json libxml mbstring openssl pcntl \
    pcre pdo posix pdo_sqlite phar random readline redis reflection session \
    simplexml soap sockets sodium spl standard tokenizer xml xmlreader \
    xmlwriter zip zlib

case "$DATABASE_MODULE" in
    mysqli) require_modules mysqli mysqlnd pdo_mysql ;;
    pgsql) require_modules pgsql pdo_pgsql ;;
    *) fail "unknown DATABASE_MODULE: $DATABASE_MODULE" ;;
esac

if [ "$BUILD_XDEBUG" = "1" ]; then
    require_modules xdebug
else
    forbid_modules xdebug
fi

pass "PHP runtime/modules ($ACTUAL_PHP_VERSION)"

# ---------------------------------------------------------------------------
# Dynamic linker: missing shared objects or unresolved symbols.
# Catches ABI breaks such as nginx built against a newer OpenSSL than runtime.
# ---------------------------------------------------------------------------
scanned=0
broken=0
for dir in /usr/bin /usr/sbin /usr/local/bin /bin /sbin; do
    [ -d "$dir" ] || continue
    for binary in "$dir"/*; do
        [ -f "$binary" ] && [ -x "$binary" ] || continue
        magic="$(head -c 4 "$binary" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
        [ "$magic" = "7f454c46" ] || continue

        scanned=$((scanned + 1))
        ldd_output="$(ldd "$binary" 2>&1)" || true
        case "$ldd_output" in
            *"not found"*|*"Error relocating"*|*"undefined symbol"*)
                echo "$ldd_output" >&2
                echo "  ^ $binary" >&2
                broken=$((broken + 1))
                ;;
        esac
    done
done

[ "$scanned" -gt 0 ] || fail "no ELF binaries found to scan"
[ "$broken" -eq 0 ] || fail "$broken binary(ies) with missing libraries/symbols"
pass "dynamic linker ($scanned binaries)"

# ---------------------------------------------------------------------------
# nginx (only in nginx variants)
# ---------------------------------------------------------------------------
if [ "$HAS_NGINX" = "1" ]; then
    command -v nginx >/dev/null 2>&1 || fail "nginx not found in PATH"
    nginx -v 2>&1 || fail "nginx -v failed"
    nginx -t 2>&1 || fail "nginx config test failed"
    nginx -V 2>&1 | grep -q -- '--with-http_stub_status_module' ||
        fail "nginx built without stub_status module"

    [ -x /usr/bin/nginx-prometheus-exporter ] ||
        fail "nginx-prometheus-exporter missing"
    /usr/bin/nginx-prometheus-exporter --version 2>&1 |
        grep -q 'nginx_exporter, version' ||
        fail "nginx-prometheus-exporter failed to run"

    pass "nginx"
else
    [ ! -x /usr/sbin/nginx ] || fail "nginx installed in non-nginx variant"
    pass "nginx correctly absent"
fi

# ---------------------------------------------------------------------------
# Supervisor and php-fpm exporter
# ---------------------------------------------------------------------------
[ -x /usr/bin/php-fpm-exporter ] || fail "php-fpm-exporter missing"
/usr/bin/php-fpm-exporter --help >/dev/null 2>&1 ||
    fail "php-fpm-exporter failed to run"

[ -x /usr/bin/supervisord ] || fail "supervisord missing"
/usr/bin/supervisord -h 2>&1 | grep -q 'Usage:' || fail "supervisord failed to run"

for helper in \
    /usr/local/bin/run-with-secrets.php \
    /usr/local/bin/docker-php-clean \
    /usr/local/bin/supervisorctl \
    /usr/local/bin/crond.sh \
    /usr/local/bin/change-user-uid-and-gid.sh \
    /etc/supervisord.conf; do
    [ -e "$helper" ] || fail "missing helper: $helper"
done

pass "supervisor/exporters/helpers"

# ---------------------------------------------------------------------------
# Go supervisord PATH handling with `user=`
# ---------------------------------------------------------------------------
# Upstream 3a1bade overwrites PATH for programs that set `user=`. Its non-root
# value omits /usr/local/sbin, where php-fpm lives, so `docker-php-entrypoint
# php-fpm` breaks. Keep checking this even after patching supervisord at build.
PATH_TEST_CONFIG=/tmp/supervisord-path-test.ini
cat > "$PATH_TEST_CONFIG" <<'EOF'
[supervisord]
logfile=/dev/null
pidfile=/tmp/supervisord-path-test.pid
nodaemon=true

[program:pathtest]
command=sh -c 'command -v php-fpm || true; command -v docker-php-entrypoint || true'
user=www-data
stdout_logfile=/dev/stdout
redirect_stderr=true
autostart=true
autorestart=false
startsecs=0
EOF

PATH_TEST_OUTPUT="$(timeout 5 /usr/bin/supervisord -c "$PATH_TEST_CONFIG" 2>&1 || true)"
case "$PATH_TEST_OUTPUT" in
    *"/usr/local/sbin/php-fpm"*) ;;
    *)
        echo "$PATH_TEST_OUTPUT" >&2
        fail "supervisord user= PATH lost /usr/local/sbin (php-fpm)"
        ;;
esac
rm -f "$PATH_TEST_CONFIG" /tmp/supervisord-path-test.pid

pass "supervisord user= PATH"

echo "ALL CHECKS PASSED"
