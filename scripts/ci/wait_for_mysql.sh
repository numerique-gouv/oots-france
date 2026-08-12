#!/bin/sh
# Attend que la base de Domibus accepte des connexions.
#
# La sonde est un `mysqladmin ping` **sur TCP**, et non la présence de « ready
# for connections » dans les journaux : l'image en écrit deux, une pour
# l'instance temporaire qui crée la base au premier démarrage, une pour le
# serveur définitif. Guetter le message rend donc la main pendant
# l'initialisation, juste avant un redémarrage — et Domibus, lancé dans la
# foulée, échoue à se connecter.
#
# Le `-h 127.0.0.1` est ce qui fait la différence : l'instance d'initialisation
# écoute sur une socket Unix seulement, jamais sur le réseau. Y répondre prouve
# que c'est bien le serveur définitif qui est en place.
#
# Usage : scripts/ci/wait_for_mysql.sh [délai max en secondes ; 300 par défaut]

set -e

RACINE=$(cd "$(dirname "$0")/../.." && pwd)

# Le mot de passe se prélève par `sed` plutôt qu'en chargeant le fichier : rien
# ne garantit qu'il traverse une interprétation par le shell.
[ -n "$MYSQL_ROOT_PASSWORD" ] || [ ! -f "$RACINE/.env.domibus" ] || \
  MYSQL_ROOT_PASSWORD=$(sed -n 's/^MYSQL_ROOT_PASSWORD=//p' "$RACINE/.env.domibus" | head -n 1)

# Le laisser vide donnerait un `-p` nu, sur lequel `mysqladmin` réclame le mot de
# passe — sur une invite que la redirection de la sonde rend invisible, et qui
# ferait attendre le délai entier sans qu'on sache pourquoi.
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "❌ MYSQL_ROOT_PASSWORD introuvable, ni dans l'environnement ni dans $RACINE/.env.domibus." >&2
  exit 1
fi

DELAI_MAX="${1:-300}"

echo "Attente de MySQL (au plus ${DELAI_MAX} s)…"

DEBUT=$(date +%s)
while true; do
  if docker compose exec -T mysql \
    mysqladmin ping -h 127.0.0.1 -u root -p"$MYSQL_ROOT_PASSWORD" --silent >/dev/null 2>&1; then
    echo "MySQL répond après $(($(date +%s) - DEBUT)) s."
    exit 0
  fi

  if [ $(($(date +%s) - DEBUT)) -gt "$DELAI_MAX" ]; then
    # La sonde tait sa propre erreur à chaque tour, sans quoi elle inonderait la
    # sortie pendant tout le démarrage. L'état du service est donc le seul moyen
    # de distinguer une base lente d'un conteneur mort dès la première seconde.
    echo "❌ MySQL n'a pas répondu après ${DELAI_MAX} s. État du service :" >&2
    docker compose ps mysql >&2
    docker compose logs --tail 20 mysql >&2
    exit 1
  fi

  sleep 3
done
