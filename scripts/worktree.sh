#!/bin/sh
# Crée un worktree git pour travailler en parallèle (agents LLM ou humains).
# Le worktree est créé dans .worktrees/ (répertoire non versionné), avec une
# branche du même nom, et les fichiers d'environnement non versionnés y sont
# recopiés.
#
# Usage : scripts/worktree.sh <nom-de-branche>

set -e

if [ -z "$1" ]; then
  echo "Usage : scripts/worktree.sh <nom-de-branche>" >&2
  exit 1
fi

NOM="$1"
# Lancé depuis un worktree, --show-toplevel renverrait la racine de ce
# worktree, et le nouveau worktree s'y retrouverait imbriqué : on remonte au
# dépôt principal, dont --git-common-dir donne toujours le répertoire .git.
RACINE="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")"
CHEMIN="$RACINE/.worktrees/$NOM"

if git show-ref --verify --quiet "refs/heads/$NOM"; then
  git worktree add "$CHEMIN" "$NOM"
else
  git worktree add -b "$NOM" "$CHEMIN"
fi

for fichier in .env .env.oots .env.domibus docker-compose.override.yml; do
  if [ -f "$RACINE/$fichier" ]; then
    cp "$RACINE/$fichier" "$CHEMIN/$fichier"
  fi
done

echo
echo "Worktree créé : $CHEMIN (branche $NOM)"
echo "Pour lancer la pile complète en parallèle d'un autre worktree, modifier"
echo "PORT_OOTS_FRANCE et PORT_DOMIBUS dans $CHEMIN/.env au préalable."
echo "Suppression : git worktree remove $CHEMIN"
