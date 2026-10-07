#!/bin/sh
# Raises a complete local installation from a freshly cloned repository:
# environment files, databases, configured gateway, schema applied. After which
# `make up` is enough to start the application.
#
# This is the local transposition of what .github/workflows/e2e.yml does on a
# runner: the two sequences of steps must stay in step, failing which an install
# that works in CI stops working on a machine.
#
# Usage: make setup   (or scripts/setup.sh)
#
# Replayable: an existing configuration is kept, and each step does only what it
# is missing.

set -e

cd "$(dirname "$0")/.."

echo "→ Fichiers d'environnement"

MANQUANTS=""
for fichier in .env .env.domibus .env.oots .env.postgres; do
  [ -e "$fichier" ] || MANQUANTS="$MANQUANTS $fichier"
done

if [ -z "$MANQUANTS" ]; then
  echo "  Déjà présents : conservés tels quels."
  # This is the branch where a template that gained a variable goes unnoticed:
  # nothing rewrites a file that is already there. The other one has just had
  # prepare_environment.sh make the same check.
  scripts/check_environment.sh
else
  echo "  Manquants :$MANQUANTS"
  # On a partial installation, prepare_environment.sh stops of its own accord
  # rather than overwrite what is already there. Naming the missing ones here is
  # the only way to know: its own refusal cites the files that are present.
  scripts/ci/prepare_environment.sh
fi

# Domibus's database is created on the container's first start, and the gateway
# fails if it connects before that.
echo "→ MySQL, la base de la passerelle"
docker compose up --detach mysql
scripts/ci/wait_for_mysql.sh

echo "→ Passerelle Domibus"
# The configuration directory is a bind mount, which the image populates on its
# first start. Created here rather than left to the daemon: under a VM with a
# shared filesystem, the daemon fails to change its owner and then refuses to
# start the container.
mkdir -p domibus
docker compose up --detach domibus

# Tomcat takes a long time to deploy the webapp: building here fills that dead
# time rather than waiting it out.
echo "→ Image de l'application, pendant le déploiement de la webapp"
docker compose build web

scripts/ci/wait_for_domibus.sh

# The certificates shipped with the image are public and shared by every
# installation: the script generates others, and reads its credentials in the
# .env files prepared above. It ends with a test AS4 message, whose
# acknowledgement it waits for.
echo "→ Configuration de la passerelle : keystore, truststore, PMode, compte d'accès"
scripts/configure_domibus.sh

# The notification rules (`wsplugin.push.rules`) cannot be changed through the
# API: they live only in the plugin's properties file, which the previous script
# writes, and take effect only here.
echo "→ Redémarrage de la passerelle, pour activer ses notifications"
docker compose restart domibus
scripts/ci/wait_for_domibus.sh

echo "→ PostgreSQL, l'état des échanges et la file des jobs"
docker compose up --detach postgres
scripts/ci/wait_for_postgres.sh
docker compose run --rm --no-deps web bundle exec rails db:prepare
# The restricted role and its privileges, replayed after `db:prepare` for the
# reason `lib/database_privileges.rb` gives.
docker compose run --rm --no-deps web bundle exec rails db:privileges
# `db:prepare` loads the seeds only when it creates the database: on an install
# already made, it would migrate without laying down the demonstration data the
# console is read against. The seed is idempotent, so calling it every time
# costs nothing.
docker compose run --rm --no-deps web bundle exec rails db:seed

cat <<'FIN'

✅ Installation terminée. Les bases et la passerelle tournent déjà.

   make up    lance l'application et son worker
   make e2e   joue un échange OOTS complet à travers la passerelle
   make       liste le reste
FIN
