#!/usr/bin/env bash
# Validates the messages this repository produces against the official
# Schematron rules of the TDD. Kept out of the unit suite: validation downloads
# artefacts and requires Java (through Docker where Java is not installed).
#
# Usage: scripts/validate_schematron.sh [tdd_version]
#
# Exit: 0 if the messages conform, 2 if a rule is violated, 1 for any other
# failure (download, compilation).
set -Eeuo pipefail

# `set -e` would propagate the failing tool's exit code as it is, and Saxon
# returns 2 on a file it cannot find — the code this script reserves for "rule
# violated". CI would read a non-conformance there and refuse to replay.
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

# Each artefact is produced under a provisional name, then moved into its final
# place once complete: an interruption never leaves behind a truncated file or a
# half-filled directory that its mere presence would later pass off as valid.
# Failing which, a network cut mid-download would freeze into the continuous
# integration cache, and the failure would clear only by invalidating the key by
# hand.
find "$outils" -name '*.partiel' -exec rm -rf {} + 2> /dev/null || true

# ----------------------------------------------------------------- tooling
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

# `java` is not installed everywhere; Docker takes over where it is not.
if command -v java > /dev/null 2>&1; then
  saxon() { java -jar "$outils/saxon.jar" "$@"; }
else
  saxon() {
    docker run --rm -v "$outils":/outils -w /outils eclipse-temurin:21-jre \
      java -jar /outils/saxon.jar "${@//$outils\//\/outils\/}"
  }
fi

# ------------------------------------------------------- Schematron rules
SCHEMATRONS=(EDM-REQ-C EDM-REQ-S EDM-RESP-C EDM-RESP-S EDM-ERR-C EDM-ERR-S EDM-ebMS)

mkdir -p "$outils/sch"

# Each rule is guarded by its own file, and not by the presence of the
# directory: continuous integration caches `.schematron` under a key that depends
# only on the TDD version, so a rule added here would never be fetched onto an
# already warm cache. The `.partiel` + `mv` pair keeps atomicity per artefact.
for regle in "${SCHEMATRONS[@]}"; do
  if [ ! -f "$outils/sch/$regle.sch" ]; then
    echo "→ Téléchargement de la règle $regle des TDD $VERSION_TDD"
    telechargeArtefactTdd "OOTS-EDM/sch/$regle.sch" "$outils/sch/$regle.sch.partiel"
    mv "$outils/sch/$regle.sch.partiel" "$outils/sch/$regle.sch"
  fi
done

# The code lists the rules include are fetched as a block: their directory
# appears only once they have all been downloaded.
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

# ----------------------------------------------------- messages to validate
echo "→ Production des messages par le code du dépôt"
(cd "$racine" && bundle exec rake "oots:messages[$messages]")

# ------------------------------------------------------------- validation
enEchec=0
valide() {
  local message="$1" regle="$2"
  saxon -s:"$messages/$message.xml" -xsl:"$outils/sch/$regle.xsl" -o:"$messages/$message.$regle.svrl" \
    > /dev/null

  if ! python3 "$racine/scripts/summarize_schematron.py" \
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
valide erreurExpiration EDM-ERR-C
valide erreurExpiration EDM-ERR-S

# The ebMS headers fall under a rule of their own, whose contexts are anchored
# on `//eb:Messaging`: the document `EbmsHeaderBuilder` produces is enough for
# it, without the SOAP envelope that surrounds it on the wire.
valide requete.entete EDM-ebMS
valide reponse.entete EDM-ebMS
valide erreur.entete EDM-ebMS
valide erreurRequeteInvalide.entete EDM-ebMS
valide erreurCapaciteNonSupportee.entete EDM-ebMS
valide erreurExpiration.entete EDM-ebMS

# Code 2 for a rule violation, distinct from the 1 any other failure returns
# (download, compilation): the caller can then retry a network fluke without
# replaying a non-conformance, which will not heal on its own.
if [ "$enEchec" -ne 0 ]; then
  echo
  echo "✗ Des règles Schematron sont violées."
  exit 2
fi

echo
echo "✓ Les messages et leurs entêtes ebMS sont conformes aux TDD $VERSION_TDD."
