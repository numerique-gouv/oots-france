#!/bin/sh
# Monte une installation locale complète à partir d'un dépôt fraîchement cloné :
# fichiers d'environnement, bases de données, passerelle configurée, schéma
# appliqué. Après quoi `make up` suffit à lancer l'application.
#
# C'est la transposition locale de ce que .github/workflows/e2e.yml fait sur un
# runner : les deux suites d'étapes doivent rester en phase, faute de quoi une
# installation qui marche en CI cesse de marcher sur un poste.
#
# Usage : make setup   (ou scripts/setup.sh)
#
# Rejouable : une configuration existante est conservée, et chaque étape se
# contente de ce qui lui manque.

set -e

cd "$(dirname "$0")/.."

# Les valeurs d'un .env* ne sont pas chargeables par un `.` : elles portent des
# accolades JSON et des `&`. On y prélève celles dont la suite a besoin.
lisVariable() {
  valeur=$(sed -n "s/^$1=//p" "$2" | head -n 1)
  if [ -z "$valeur" ]; then
    echo "❌ $1 est absente de $2 : compléter ce fichier." >&2
    exit 1
  fi
  echo "$valeur"
}

echo "→ Fichiers d'environnement"

MANQUANTS=""
for fichier in .env .env.domibus .env.oots .env.postgres; do
  [ -e "$fichier" ] || MANQUANTS="$MANQUANTS $fichier"
done

if [ -z "$MANQUANTS" ]; then
  echo "  Déjà présents : conservés tels quels."
else
  echo "  Manquants :$MANQUANTS"
  # Sur une installation partielle, prepare_environment.sh s'arrête de lui-même
  # plutôt que d'écraser ce qui existe déjà. Nommer les absents ici est le seul
  # moyen de le savoir : son propre refus ne cite que les fichiers présents.
  scripts/ci/prepare_environment.sh
fi

# Exportées pour scripts/configure_domibus.sh, qui exige les identifiants plutôt
# que de les déduire : le compte qu'il crée dans la passerelle doit être celui
# que l'application lui présentera.
PORT_DOMIBUS=$(lisVariable PORT_DOMIBUS .env)
MOT_DE_PASSE_MAGASINS=$(lisVariable MOT_DE_PASSE_MAGASINS .env)
LOGIN_API_REST=$(lisVariable LOGIN_API_REST .env.oots)
MOT_DE_PASSE_API_REST=$(lisVariable MOT_DE_PASSE_API_REST .env.oots)
export PORT_DOMIBUS MOT_DE_PASSE_MAGASINS LOGIN_API_REST MOT_DE_PASSE_API_REST

# La base de Domibus se crée au premier démarrage du conteneur, et la passerelle
# échoue si elle s'y connecte avant.
echo "→ MySQL, la base de la passerelle"
docker compose up --detach mysql
scripts/ci/wait_for_mysql.sh

echo "→ Passerelle Domibus"
# Le répertoire de configuration est un montage lié, que l'image peuple à son
# premier démarrage. Le créer ici plutôt que de laisser faire le démon : sous
# une VM à système de fichiers partagé, il échoue à en changer le propriétaire
# et refuse alors de démarrer le conteneur.
mkdir -p domibus
docker compose up --detach domibus

# Le déploiement de la webapp par Tomcat est long : construire ici occupe ce
# temps mort plutôt que de l'attendre.
echo "→ Image de l'application, pendant le déploiement de la webapp"
docker compose build web

scripts/ci/wait_for_domibus.sh

# Les certificats livrés avec l'image sont publics et partagés par toutes les
# installations : le script en génère d'autres. Il finit par un message AS4 de
# test, dont il attend l'acquittement.
echo "→ Configuration de la passerelle : magasins, PMode, compte d'accès"
scripts/configure_domibus.sh

# Les règles de notification (`wsplugin.push.rules`) ne sont pas modifiables par
# l'API : elles ne vivent que dans le fichier de propriétés du plugin, que le
# script précédent écrit, et ne prennent effet qu'ici.
echo "→ Redémarrage de la passerelle, pour activer ses notifications"
docker compose restart domibus
scripts/ci/wait_for_domibus.sh

echo "→ PostgreSQL, l'état des conversations et la file des travaux"
docker compose up --detach postgres
scripts/ci/wait_for_postgres.sh
docker compose run --rm --no-deps web bundle exec rails db:prepare

cat <<'FIN'

✅ Installation terminée. Les bases et la passerelle tournent déjà.

   make up    lance l'application et son worker
   make e2e   joue un échange OOTS complet à travers la passerelle
   make       liste le reste
FIN
