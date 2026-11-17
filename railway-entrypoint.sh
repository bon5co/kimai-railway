#!/bin/bash
# Kimai on Railway: Apache on the injected PORT, administrator from variables, one API access token seeded.
set -eu

die() { echo "kimai-railway: $*" >&2; exit 1; }

[ -n "${DATABASE_URL:-}" ] || die "DATABASE_URL is empty - Kimai has no database to install into"
[ -n "${ADMINPASS:-}" ] || die "ADMINPASS is empty - there would be no way to sign in"
[ "${#ADMINPASS}" -ge 8 ] || die "ADMINPASS must be at least 8 characters"
[ -n "${KIMAI_API_TOKEN:-}" ] || die "KIMAI_API_TOKEN is empty - there would be no API credential"
[ "${#KIMAI_API_TOKEN}" -ge 32 ] || die "KIMAI_API_TOKEN must be at least 32 characters"
[ "${#KIMAI_API_TOKEN}" -le 100 ] || die "KIMAI_API_TOKEN must be at most 100 characters"

# Railway injects PORT (8080) and its healthcheck dials it, so Apache has to listen there.
P="${PORT:-8080}"
sed -i "s/^Listen .*/Listen $P/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:$P>/" /etc/apache2/sites-enabled/*.conf
echo "kimai-railway: apache port=$P var/data owner=$(stat -c %u:%g /opt/kimai/var/data 2>/dev/null || echo none)"
# Railway restores the mpm_event module the upstream image disabled in a later layer (OCI whiteouts are ignored), so
# Apache dies with "More than one MPM loaded". Force prefork, which mod_php needs. Idempotent.
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod mpm_prefork >/dev/null 2>&1 || true

# The upstream entrypoint installs the schema, creates the administrator and then execs Apache. The access token
# needs both, so a watcher waits for the "Kimai is ready" marker the entrypoint writes and seeds the token once.
rm -f /opt/kimai/var/installed
(
  n=0
  until [ -f /opt/kimai/var/installed ]; do
    n=$((n + 1)); [ "$n" -le 600 ] || { echo "kimai-railway: install never finished, no API token seeded"; exit 0; }
    sleep 2
  done
  php -r '
    $u = parse_url(getenv("DATABASE_URL"));
    $pdo = new PDO(sprintf("mysql:host=%s;port=%d;dbname=%s", $u["host"], $u["port"] ?? 3306, ltrim($u["path"], "/")),
      urldecode($u["user"]), urldecode($u["pass"]), [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $tok = getenv("KIMAI_API_TOKEN");
    $q = $pdo->prepare("SELECT id FROM kimai2_users WHERE username = ?"); $q->execute(["admin"]);
    $uid = $q->fetchColumn();
    if (!$uid) { echo "kimai-railway: no admin user, no API token seeded\n"; exit(0); }
    $pdo->prepare("DELETE FROM kimai2_access_token WHERE name = ? AND token <> ?")->execute(["railway-agent", $tok]);
    $q = $pdo->prepare("SELECT id FROM kimai2_access_token WHERE token = ?"); $q->execute([$tok]);
    if ($q->fetchColumn()) { echo "kimai-railway: API token already present\n"; exit(0); }
    $pdo->prepare("INSERT INTO kimai2_access_token (user_id, token, name) VALUES (?, ?, ?)")->execute([$uid, $tok, "railway-agent"]);
    echo "kimai-railway: API token seeded for user $uid\n";
  ' || echo "kimai-railway: API token seeding failed"
) &

exec /entrypoint.sh
