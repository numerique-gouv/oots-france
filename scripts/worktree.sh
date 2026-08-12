#!/bin/sh
# Crée un worktree git pour travailler en parallèle (agents LLM ou humains).
# Le worktree est créé dans .worktrees/ (répertoire non versionné), avec une
# branche du même nom, et les fichiers d'environnement non versionnés y sont
# recopiés — leurs ports décalés pour que la pile du worktree puisse tourner en
# même temps que celle du dépôt principal.
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

# Les ports qu'un .env publie sur l'hôte, lus au lieu d'être énumérés ici :
# `web`, `domibus` et `postgres` n'en écrivent aucun en dur, donc ajouter une
# variable `PORT_` à .env suffit à la faire décaler avec les autres.
ports_declares() {
  [ -f "$1" ] || return 0
  sed -n 's/^PORT_[A-Z_0-9]*=\([0-9][0-9]*\).*/\1/p' "$1"
}

DECALAGE_MAX=99

# Tout le décalage se calcule à partir de ce fichier.
if [ ! -r "$RACINE/.env" ]; then
  echo "❌ $RACINE/.env introuvable ou illisible." >&2
  echo "   Le créer à partir de .env.template avant de créer un worktree." >&2
  exit 1
fi

# Une ligne `PORT_` hors de cette forme serait ignorée partout — ni réservée,
# ni décalée, ni affichée — et la pile du worktree publierait ce port-là sur
# celui du voisin. Deux formes s'y glissent facilement :
#
# Un espace après le `=`, que le gabarit laisse avant son commentaire. Docker
# compose ne reconnaît d'ailleurs un commentaire de fin de ligne que précédé
# d'une espace : `PORT_X=8180#note` vaut pour lui la valeur `8180#note`, qu'il
# refuse en `invalid hostPort`.
#
# Un zéro de tête, plus insidieux : `port_pris` compare des chaînes, donc le
# `03001` réservé par un voisin ne correspond jamais au `3001` calculé ici, et
# les deux piles se retrouvent sur le même port sans un mot.
refuse_ports_mal_formes() {
  MAL_FORMEES="$(grep -n '^PORT_' "$1" | grep -vE '^[0-9]+:PORT_[A-Z_0-9]*=[1-9][0-9]*([[:space:]].*)?$' || true)"
  [ -n "$MAL_FORMEES" ] || return 0

  echo "❌ $1 déclare des ports que ce script ne sait pas lire :" >&2
  echo "$MAL_FORMEES" >&2
  echo "   Attendu : PORT_X=<entier positif, sans zéro de tête>, un commentaire" >&2
  echo "   éventuel devant être précédé d'une espace." >&2
  exit 1
}

refuse_ports_mal_formes "$RACINE/.env"

# Un .env de worktree illisible ne peut pas être ignoré : les ports qu'il
# réserve resteraient invisibles et deux piles se les disputeraient. Le
# détecter ici plutôt que dans la substitution ci-dessous, dont l'échec
# arrêterait le script sous `set -e` sur le seul message de `sed`.
for fichier in "$RACINE"/.worktrees/*/.env; do
  [ -e "$fichier" ] || continue
  if [ ! -r "$fichier" ]; then
    echo "❌ $fichier est illisible : les ports qu'il réserve resteraient invisibles." >&2
    exit 1
  fi
  refuse_ports_mal_formes "$fichier"
done

PORTS_PRINCIPAUX="$(ports_declares "$RACINE/.env")"

# Ce que le .env déclare est validé une fois ici, où le fichier fautif peut
# encore être nommé. Sans quoi : une liste vide fait retenir un décalage sans
# qu'aucun port n'ait été testé, un zéro de tête est lu en octal par
# l'arithmétique du shell, et une valeur assez grande la fait déborder sur un
# « Illegal number » qui ne dit ni le fichier ni la ligne.
if [ -z "$PORTS_PRINCIPAUX" ]; then
  echo "❌ Aucune variable PORT_ exploitable dans $RACINE/.env." >&2
  echo "   La compléter à partir de .env.template." >&2
  exit 1
fi

rejette_port() {
  echo "❌ $RACINE/.env déclare le port $1, hors de 1–$((65535 - DECALAGE_MAX))." >&2
  echo "   Un port décalé doit rester dans l'espace TCP, zéro de tête exclu." >&2
  exit 1
}

for port in $PORTS_PRINCIPAUX; do
  # La forme d'abord, la plage ensuite : six chiffres sont déjà absurdes pour
  # un port, et le motif écarte du même coup les valeurs qu'aucune arithmétique
  # 64 bits ne représente, sur lesquelles la comparaison échouerait.
  case "$port" in 0*|??????*) rejette_port "$port" ;; esac
  [ "$port" -le $((65535 - DECALAGE_MAX)) ] || rejette_port "$port"
done

PORTS_RESERVES="$PORTS_PRINCIPAUX
$(for fichier in "$RACINE"/.worktrees/*/.env; do
  ports_declares "$fichier"
done)"

if ! command -v ss >/dev/null 2>&1; then
  echo "⚠️  ss introuvable : seuls les ports déclarés par les .env du dépôt" >&2
  echo "   seront évités, pas ceux qu'un autre programme écoute déjà." >&2
fi

# Un port est pris s'il est déclaré par un .env du dépôt, et à défaut s'il
# écoute. C'est la déclaration qui porte le garde-fou : elle voit les piles
# éteintes, qui gardent leurs ports, et elle vaut pour tout worktree du dépôt
# quel que soit le démon Docker qui l'exécute.
#
# `ss` ne rattrape que le port occupé sans être déclaré nulle part, et sur le
# seul démon local : un port alloué par un démon voisin lui échappe. Là où `ss`
# n'existe pas, la déclaration joue seule.
port_pris() {
  if echo "$PORTS_RESERVES" | grep -qx "$1"; then
    return 0
  fi
  ss -Htln "sport = :$1" 2>/dev/null | grep -q .
}

pile_libre() {
  for port in $PORTS_PRINCIPAUX; do
    port_pris $((port + $1)) && return 1
  done
  return 0
}

# Un décalage unique pour toute la pile : la console Domibus d'un worktree
# décalé de 7 répond sur 8187 quand son serveur répond sur 3007. Les ports d'une
# même pile restent ainsi lisibles ensemble.
DECALAGE=1
while ! pile_libre "$DECALAGE"; do
  DECALAGE=$((DECALAGE + 1))
  if [ "$DECALAGE" -gt "$DECALAGE_MAX" ]; then
    echo "❌ Aucun jeu de ports libre entre +1 et +$DECALAGE_MAX de ceux du dépôt principal." >&2
    echo "   Éteindre une pile, ou supprimer un worktree devenu inutile." >&2
    exit 1
  fi
done

if git show-ref --verify --quiet "refs/heads/$NOM"; then
  git worktree add "$CHEMIN" "$NOM"
else
  git worktree add -b "$NOM" "$CHEMIN"
fi

# La valeur s'arrête au premier caractère non numérique, ce qui préserve un
# `# commentaire` de fin de ligne — le .env du dépôt en porte un par port.
#
# `[ -n "$ligne" ]` en plus de `read` : sur une dernière ligne non terminée par
# un saut de ligne, `read` remplit la variable mais rend un statut non nul, et
# la boucle abandonnerait cette dernière ligne sans rien signaler.
#
# `printf` et non `echo` : celui de dash interprète les antislashs sans `-e`,
# et couperait en deux un mot de passe qui en contient un.
decale_ports() {
  while IFS= read -r ligne || [ -n "$ligne" ]; do
    case "$ligne" in
      PORT_*=[0-9]*)
        valeur="${ligne#*=}"
        port="${valeur%%[!0-9]*}"
        printf '%s\n' "${ligne%%=*}=$((port + DECALAGE))${valeur#$port}"
        ;;
      *)
        printf '%s\n' "$ligne"
        ;;
    esac
  done
}

# Les URLs que l'application annonce d'elle-même visent ces mêmes ports publiés
# — URL_OOTS_FRANCE la première. Les laisser sur ceux du dépôt principal ferait
# pointer le worktree vers la pile du voisin. Ce qui vise un nom de service
# docker (`http://domibus:8080`, `http://web:4000`) ne bouge pas : ces ports-là
# sont internes au réseau du conteneur.
#
# Deux expressions par port, faute d'un `\b` que seul GNU sed connaît : le port
# suivi d'un non-chiffre, et le port en fin de ligne. L'approximation est plus
# large qu'une frontière de mot, qui ne coupe pas entre un chiffre et une
# lettre — sans effet sur les URLs du dépôt, où un port finit toujours la ligne
# ou précède un `/`.
REECRITURE_URLS=""
for port in $PORTS_PRINCIPAUX; do
  REECRITURE_URLS="$REECRITURE_URLS
s|localhost:$port\\([^0-9]\\)|localhost:$((port + DECALAGE))\\1|g
s|localhost:$port\$|localhost:$((port + DECALAGE))|g"
done

# Les `.env*` sont pris par motif, ce qui dispense d'en tenir la liste ;
# `docker-compose.override.yml` ne suit aucun motif et reste nommé, donc un
# futur fichier de configuration hors `.env*` sera à ajouter ici.
#
# Seul .env voit ses `PORT_` décalés, parce que lui seul les publie sur l'hôte.
# Ceux des autres fichiers désignent un port à l'intérieur du réseau docker —
# `PORT_BASE_DE_DONNEES` est le 5432 sur lequel écoute le conteneur, que le
# décalage ferait viser dans le vide.
for source in "$RACINE"/.env* "$RACINE/docker-compose.override.yml"; do
  # Ces deux gardes doivent rester hors du pipeline ci-dessous : dans le `case`
  # qui l'alimente, `continue` ne quitterait que le sous-shell de gauche, et
  # `sed` créerait un fichier vide au lieu que le fichier soit sauté.
  case "$source" in *.template) continue ;; esac
  [ -f "$source" ] || continue

  # Lecture puis transformation, et non les deux dans un pipeline : celui-ci ne
  # rend que le statut de son dernier élément tant que `pipefail` n'est pas
  # activé, ce que ce script ne fait pas. Un fichier illisible ferait sinon
  # réussir `sed` sur une entrée vide, donc écrire une destination vide en
  # annonçant le succès.
  if ! LIGNES="$(case "$source" in
    */.env) decale_ports < "$source" ;;
    *) cat "$source" ;;
  esac)"; then
    echo "❌ Lecture de $source impossible." >&2
    echo "   Le worktree est créé mais inutilisable : git worktree remove $CHEMIN" >&2
    exit 1
  fi

  printf '%s\n' "$LIGNES" | sed "$REECRITURE_URLS" > "$CHEMIN/$(basename "$source")"
done

echo
echo "Worktree créé : $CHEMIN (branche $NOM)"
echo "Ports décalés de +$DECALAGE :"
sed -n 's/^\(PORT_[A-Z_0-9]*=[0-9][0-9]*\).*/  \1/p' "$CHEMIN/.env"
echo "Suppression : git worktree remove $CHEMIN"
