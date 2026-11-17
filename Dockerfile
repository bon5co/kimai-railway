# Kimai for Railway.
#
# Kimai (kimai/kimai, AGPL-3.0) is a self-hosted time-tracking application with a REST API. The upstream image is
# correct as shipped, but a fresh public Railway deploy driven by an agent needs four things it does not do:
#
# 1. Kimai's API accepts only access tokens that a signed-in person creates in the web interface, so a deploy has
#    no API credential until someone clicks through the UI. railway-entrypoint.sh seeds one access token for the
#    administrator from KIMAI_API_TOKEN once the database is installed.
# 2. Apache listens on 8001; Railway's healthcheck dials the injected PORT, so the script rewrites the listen port.
# 3. The default administrator is created only when ADMINMAIL and ADMINPASS are set; the script refuses to start
#    without a password and the image bakes a placeholder address.
# 4. The script fails fast on a missing database URL instead of waiting on it forever.
#
# The application is otherwise unchanged: same code, same entrypoint, same configuration keys.
# upstream: kimai/kimai
FROM kimai/kimai2:2.72.0@sha256:ee3838cd6841b716cb0992a995a1d3cc60dbd5332bb21946565b31d02aaa4eec

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV ADMINMAIL=admin@example.com \
    APP_ENV=prod \
    TRUSTED_PROXIES=* \
    MAILER_FROM=kimai@example.com \
    MAILER_URL=null://localhost

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
