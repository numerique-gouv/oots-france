#!/usr/bin/env bash
# Valide les messages produits par ce dépôt contre les règles Schematron
# officielles des TDD. Exclu de `npm test` : la validation télécharge des
# artefacts et exige Java (via Docker si Java n'est pas installé).
#
# Usage : scripts/valideSchematron.sh [version_tdd]
#
# Sortie : 0 si les messages sont conformes, 2 si une règle est violée, 1 pour
# toute autre défaillance (téléchargement, compilation).
set -Eeuo pipefail

# `set -e` propagerait tel quel le code de sortie de l'outil défaillant, or
# Saxon rend 2 sur un fichier introuvable — le code que ce script réserve à
# « règle violée ». La CI y lirait une non-conformité et refuserait de rejouer.
trap 'exit 1' ERR

VERSION_TDD="${1:-2.0.1}"
PROJET_GITLAB=138  # oots/tdd/tdd_chapters sur code.europa.eu
VERSION_SCHXSLT=1.10.1
VERSION_SAXON=10.9

racine="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
outils="$racine/.schematron/$VERSION_TDD"
messages="$outils/messages"
mkdir -p "$outils" "$messages"

telechargeArtefactTdd() {
  local chemin="$1" destination="$2"
  local encode
  encode=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$chemin")
  curl -sSf -o "$destination" \
    "https://code.europa.eu/api/v4/projects/$PROJET_GITLAB/repository/files/$encode/raw?ref=$VERSION_TDD"
}

# Chaque artefact est produit sous un nom provisoire, puis déplacé à sa place
# définitive une fois complet : une interruption ne laisse jamais derrière elle
# un fichier tronqué ou un répertoire à demi rempli que sa seule présence ferait
# ensuite passer pour valide. Sans quoi une coupure réseau en cours de
# téléchargement se figerait dans le cache de l'intégration continue, et
# l'échec ne se résorberait qu'en invalidant la clé à la main.
find "$outils" -name '*.partiel' -exec rm -rf {} + 2> /dev/null || true

# ---------------------------------------------------------------- outillage
if [ ! -f "$outils/saxon.jar" ]; then
  echo "→ Téléchargement de Saxon-HE $VERSION_SAXON"
  curl -sSf -o "$outils/saxon.jar.partiel" \
    "https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/$VERSION_SAXON/Saxon-HE-$VERSION_SAXON.jar"
  mv "$outils/saxon.jar.partiel" "$outils/saxon.jar"
fi

if [ ! -d "$outils/schxslt" ]; then
  echo "→ Téléchargement de SchXslt $VERSION_SCHXSLT"
  curl -sSf -o "$outils/schxslt.jar.partiel" \
    "https://repo1.maven.org/maven2/name/dmaus/schxslt/schxslt/$VERSION_SCHXSLT/schxslt-$VERSION_SCHXSLT.jar"
  unzip -qo "$outils/schxslt.jar.partiel" -d "$outils/schxslt.partiel"
  rm -f "$outils/schxslt.jar.partiel"
  mv "$outils/schxslt.partiel" "$outils/schxslt"
fi

# `java` n'est pas installé partout ; Docker prend le relais le cas échéant.
if command -v java > /dev/null 2>&1; then
  saxon() { java -jar "$outils/saxon.jar" "$@"; }
else
  saxon() {
    docker run --rm -v "$outils":/outils -w /outils eclipse-temurin:21-jre \
      java -jar /outils/saxon.jar "${@//$outils\//\/outils\/}"
  }
fi

# ------------------------------------------------------- règles Schematron
SCHEMATRONS=(EDM-REQ-C EDM-REQ-S EDM-RESP-C EDM-RESP-S EDM-ERR-C EDM-ERR-S EDM-ebMS)

mkdir -p "$outils/sch"

# Chaque règle est gardée par son propre fichier, et non par la présence du
# répertoire : l'intégration continue met `.schematron` en cache sous une clé
# qui ne dépend que de la version des TDD, si bien qu'une règle ajoutée ici ne
# serait jamais récupérée sur un cache déjà chaud. Le couple `.partiel` + `mv`
# conserve l'atomicité par artefact.
for regle in "${SCHEMATRONS[@]}"; do
  if [ ! -f "$outils/sch/$regle.sch" ]; then
    echo "→ Téléchargement de la règle $regle des TDD $VERSION_TDD"
    telechargeArtefactTdd "OOTS-EDM/sch/$regle.sch" "$outils/sch/$regle.sch.partiel"
    mv "$outils/sch/$regle.sch.partiel" "$outils/sch/$regle.sch"
  fi
done

# Les listes de codes incluses par les règles se récupèrent en bloc : leur
# répertoire n'apparaît qu'une fois toutes téléchargées.
if [ ! -d "$outils/sch/codelist-include" ]; then
  echo "→ Téléchargement des listes de codes des TDD $VERSION_TDD"
  mkdir -p "$outils/sch/codelist-include.partiel"
  python3 - "$PROJET_GITLAB" "$VERSION_TDD" "$outils/sch/codelist-include.partiel" <<'PY'
import json, os, sys, urllib.parse, urllib.request
projet, version, destination = sys.argv[1:4]
arbre = f'https://code.europa.eu/api/v4/projects/{projet}/repository/tree?ref={version}&path=OOTS-EDM/sch/codelist-include&per_page=100'
for entree in json.load(urllib.request.urlopen(arbre)):
    chemin = urllib.parse.quote('OOTS-EDM/sch/codelist-include/' + entree['name'], safe='')
    source = f'https://code.europa.eu/api/v4/projects/{projet}/repository/files/{chemin}/raw?ref={version}'
    urllib.request.urlretrieve(source, os.path.join(destination, entree['name']))
PY
  mv "$outils/sch/codelist-include.partiel" "$outils/sch/codelist-include"
fi

for regle in "${SCHEMATRONS[@]}"; do
  if [ ! -f "$outils/sch/$regle.xsl" ]; then
    echo "→ Compilation de $regle"
    saxon -s:"$outils/sch/$regle.sch" \
      -xsl:"$outils/schxslt/xslt/2.0/pipeline-for-svrl.xsl" \
      -o:"$outils/sch/$regle.xsl.partiel"
    mv "$outils/sch/$regle.xsl.partiel" "$outils/sch/$regle.xsl"
  fi
done

# ------------------------------------------------------ messages à valider
echo "→ Production des messages par le code du dépôt"
node "$racine/scripts/produisMessagesOots.js" "$messages"

# ------------------------------------------------------------- validation
enEchec=0
valide() {
  local message="$1" regle="$2"
  saxon -s:"$messages/$message.xml" -xsl:"$outils/sch/$regle.xsl" -o:"$messages/$message.$regle.svrl" \
    > /dev/null

  if ! python3 "$racine/scripts/resumeSchematron.py" \
    "$messages/$message.$regle.svrl" "$message" "$regle" ${BAVARD:+--bavard}; then
    enEchec=1
  fi
}

valide requete EDM-REQ-C
valide requete EDM-REQ-S
valide reponse EDM-RESP-C
valide reponse EDM-RESP-S
valide erreur EDM-ERR-C
valide erreur EDM-ERR-S
valide erreurRequeteInvalide EDM-ERR-C
valide erreurRequeteInvalide EDM-ERR-S
valide erreurCapaciteNonSupportee EDM-ERR-C
valide erreurCapaciteNonSupportee EDM-ERR-S

# Les entêtes ebMS relèvent d'une règle à part, dont les contextes sont ancrés
# sur `//eb:Messaging` : le document que produit `Entete#enXML()` lui suffit,
# sans l'enveloppe SOAP qui l'entoure sur le fil.
valide requete.entete EDM-ebMS
valide reponse.entete EDM-ebMS
valide erreur.entete EDM-ebMS
valide erreurRequeteInvalide.entete EDM-ebMS
valide erreurCapaciteNonSupportee.entete EDM-ebMS

# Code 2 pour une violation de règle, distinct du 1 que rend toute autre
# défaillance (téléchargement, compilation) : l'appelant peut ainsi retenter un
# aléa réseau sans rejouer une non-conformité, qui elle ne guérira pas seule.
if [ "$enEchec" -ne 0 ]; then
  echo
  echo "✗ Des règles Schematron sont violées."
  exit 2
fi

echo
echo "✓ Les messages et leurs entêtes ebMS sont conformes aux TDD $VERSION_TDD."
