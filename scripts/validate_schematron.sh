#!/usr/bin/env bash
# Validates the messages this repository produces against the official
# Schematron rules of the TDD. Kept out of the unit suite: validation downloads
# artefacts and requires Java (through Docker where Java is not installed).
#
# Usage: scripts/validate_schematron.sh [tdd_version]
#
# The tag names the line: `1.2.5` judges the messages the code writes as
# `oots-edm:v1.2`, `2.0.1` those it writes as `oots-edm:v2.0`. Each version
# keeps its own artefacts and its own messages under `.schematron/<tag>/`.
#
# Exit: 0 if the messages conform, 2 if a rule is violated, 1 for any other
# failure (download, compilation).
set -Eeuo pipefail

# `set -e` would propagate the failing tool's exit code as it is, and Saxon
# returns 2 on a file it cannot find — the code this script reserves for "rule
# violated". CI would read a non-conformance there and refuse to replay.
trap 'exit 1' ERR

VERSION_TDD="${1:-2.0.1}"

# The EDM version the tag judges, derived from the tag's own major.minor: a
# later patch on either line renders the same messages.
case "$VERSION_TDD" in
  1.2.*) SPECIFICATION_EDM='oots-edm:v1.2' ;;
  2.0.*) SPECIFICATION_EDM='oots-edm:v2.0' ;;
  *)
    echo "Version des TDD inconnue : $VERSION_TDD" >&2
    exit 1
    ;;
esac
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

# The cross-validation rules judge two messages of one exchange together. Only
# the ten that bear on messages this script renders: the seven others confront
# a message with a directory answer, which nothing here produces. None includes
# a code list.
CROISEES=(
  EDM-REQ_EDM-RESP EDM-REQ_EDM-ERR EDM-ERR_EDM-REQ2 EDM-REQ1_EDM-REQ2
  ebMS_EDM-REQ ebMS_EDM-RESP ebMS_EDM-ERR
  ebMS-REQ_ebMS-RESP ebMS-ERR_ebMS-REQ2 ebMS-REQ1_ebMS-REQ2
)

mkdir -p "$outils/crossvalidation"

# Guarded file by file, for the reason the rules above are.
for regle in "${CROISEES[@]}"; do
  if [ ! -f "$outils/crossvalidation/$regle.sch" ]; then
    echo "→ Téléchargement de la règle croisée $regle des TDD $VERSION_TDD"
    telechargeArtefactTdd "OOTS-EDM/crossvalidation/sch/$regle.sch" "$outils/crossvalidation/$regle.sch.partiel"
    mv "$outils/crossvalidation/$regle.sch.partiel" "$outils/crossvalidation/$regle.sch"
  fi
done

compile() {
  local repertoire="$1" regle="$2"
  if [ ! -f "$outils/$repertoire/$regle.xsl" ]; then
    echo "→ Compilation de $regle"
    saxon -s:"$outils/$repertoire/$regle.sch" \
      -xsl:"$outils/schxslt/xslt/2.0/pipeline-for-svrl.xsl" \
      -o:"$outils/$repertoire/$regle.xsl.partiel"
    mv "$outils/$repertoire/$regle.xsl.partiel" "$outils/$repertoire/$regle.xsl"
  fi
}

for regle in "${SCHEMATRONS[@]}"; do compile sch "$regle"; done
for regle in "${CROISEES[@]}"; do compile crossvalidation "$regle"; done

# ----------------------------------------------------- messages to validate
echo "→ Production des messages $SPECIFICATION_EDM par le code du dépôt"
(cd "$racine" && bundle exec rake "oots:messages[$messages,$SPECIFICATION_EDM]")

# ------------------------------------------------------------- validation
enEchec=0
valide() {
  local message="$1" regle="$2"
  shift 2
  saxon -s:"$messages/$message.xml" -xsl:"$outils/sch/$regle.xsl" -o:"$messages/$message.$regle.svrl" \
    > /dev/null

  if ! python3 "$racine/scripts/summarize_schematron.py" \
    "$messages/$message.$regle.svrl" "$message" "$regle" ${BAVARD:+--bavard} "$@"; then
    enEchec=1
  fi
}

# Le seul spécimen qu'on attend refusé, et le seul contrôle qui dise qu'une
# règle mord : les autres, tous conformes, ne prouvent qu'une chose — que le
# dépôt les respecte. Le verdict est inversé, et il exige que ce soient les
# règles nommées qui refusent, et aucune autre.
refuse() {
  local message="$1" regle="$2" regles="$3"
  valide "$message" "$regle" "--refus=$regles"
}

# Une paire de messages, confrontée à une règle croisée : chaque message est
# donné par le nom que la règle attend et le spécimen qui le porte —
# `edm-req=correspondant.requete`. Le document assemblé et son rapport sont
# gardés sous `paires/`, pour qu'on relise ce que la règle a lu.
croise() {
  local regle="$1"
  shift
  local assemblage=() libelle="" nom=""
  for argument in "$@"; do
    assemblage+=("${argument%%=*}=$messages/${argument#*=}.xml")
    libelle+="${libelle:+ + }${argument#*=}"
    nom+="${nom:+__}${argument#*=}"
  done

  local paire="$messages/paires/$nom.$regle"
  mkdir -p "$messages/paires"
  python3 -I "$racine/scripts/pair_messages.py" "$paire.xml" "${assemblage[@]}"
  saxon -s:"$paire.xml" -xsl:"$outils/crossvalidation/$regle.xsl" -o:"$paire.svrl" > /dev/null

  if ! python3 "$racine/scripts/summarize_schematron.py" \
    "$paire.svrl" "$libelle" "$regle" ${BAVARD:+--bavard}; then
    enEchec=1
  fi
}

# Un corps contre son propre en-tête ebMS, par le jeu croisé de sa nature.
contreSonEntete() {
  local nature="$1"
  shift
  local corps entete
  case "$nature" in
    REQ) corps=edm-req entete=evidence_request_header ;;
    RESP) corps=edm-resp entete=evidence_response_header ;;
    ERR) corps=edm-err entete=evidence_error_response_header ;;
  esac

  for message in "$@"; do
    croise "ebMS_EDM-$nature" "$entete=$message.entete" "$corps=$message"
  done
}

valide requete EDM-REQ-C
valide requete EDM-REQ-S
# La même requête, portant une personne morale : R-EDM-REQ-S016 n'admet qu'un
# sujet, donc rien d'autre ne confronte les règles du slot `LegalPerson`.
valide requetePersonneMorale EDM-REQ-C
valide requetePersonneMorale EDM-REQ-S
# La même requête, portant le slot `EvidenceProviderClassification` que la
# France écrit quand le Data Service Directory a posé une question à l'usager :
# une classification `codelist`, puis les trois types que le 3.1.4 publie.
valide requeteClassification EDM-REQ-C
valide requeteClassification EDM-REQ-S
valide requeteTroisClassifications EDM-REQ-C
valide requeteTroisClassifications EDM-REQ-S
# La même requête, demandant la distribution structurée qu'un portail nomme par
# `format`, publiée sans modèle de données : un seul `sdg:DistributedAs`, sans
# `sdg:ConformsTo`.
valide requeteFormatStructure EDM-REQ-C
valide requeteFormatStructure EDM-REQ-S
valide reponse EDM-RESP-C
valide reponse EDM-RESP-S
# La même réponse, à propos d'une personne morale : `sdg:IsAbout` étant un
# `xs:choice`, rien d'autre ne confronte la forme réduite que R-EDM-RESP-S042
# impose à la branche morale.
valide reponsePersonneMorale EDM-RESP-C
valide reponsePersonneMorale EDM-RESP-S
# Le statut étudiant, servi en JSON : `sdg:Language` dans la distribution,
# `R-EDM-RESP-C026` la tenant à la liste `LanguageCode`, et le ministère pour
# émetteur, sous ses deux noms.
valide reponseStatutEtudiant EDM-RESP-C
valide reponseStatutEtudiant EDM-RESP-S
# Le même, servi en attestation PDF : `application/pdf`, la langue, et aucun
# `ConformsTo` — que `R-EDM-RESP-C050` interdit sans le juger ici en 2.0, son
# contexte étant l'objet de premier niveau.
valide reponseStatutEtudiantPdf EDM-RESP-C
valide reponseStatutEtudiantPdf EDM-RESP-S
valide reponseDifferee EDM-RESP-C
valide reponseDifferee EDM-RESP-S
valide erreur EDM-ERR-C
valide erreur EDM-ERR-S
valide erreurRequeteInvalide EDM-ERR-C
valide erreurRequeteInvalide EDM-ERR-S
valide erreurCapaciteNonSupportee EDM-ERR-C
valide erreurCapaciteNonSupportee EDM-ERR-S
valide erreurExpiration EDM-ERR-C
valide erreurExpiration EDM-ERR-S
# La seule forme sans `requestId`, que `R-EDM-ERR-C025` n'autorise que sous
# `rs:InvalidRequestExceptionType` : rien d'autre ne confronte cette règle.
valide erreurSansIdentifiantDeRequete EDM-ERR-C
valide erreurSansIdentifiantDeRequete EDM-ERR-S
# Les deux messages du chapitre 4.9 que la France émet en fournisseur :
# l'exception qui envoie l'usager vers son espace de prévisualisation, avec
# `PreviewDescription` et, en 1.2, `PreviewMethod` ; et la réponse de succès à
# liste vide, de l'usager qui n'a rien accepté comme de celui à qui aucun
# document ne correspond, au premier échange ou au second — un seul message,
# que le même constructeur rend sans justificatif.
valide erreurPrevisualisationRequise EDM-ERR-C
valide erreurPrevisualisationRequise EDM-ERR-S
valide reponseVide EDM-RESP-C
valide reponseVide EDM-RESP-S
# Et celui qu'elle émet en requêteur : la seconde requête, qui porte
# `PreviewLocation` et, en 2.0, `ReturnLocation` — que `R-EDM-REQ-S062` apparie,
# et dont `C005` et `C120` exigent le `https://`.
valide requeteSeconde EDM-REQ-C
valide requeteSeconde EDM-REQ-S

# The ebMS headers fall under a rule of their own, whose contexts are anchored
# on `//eb:Messaging`: the document `EbmsHeaderBuilder` produces is enough for
# it, without the SOAP envelope that surrounds it on the wire.
valide requete.entete EDM-ebMS
valide requetePersonneMorale.entete EDM-ebMS
valide reponse.entete EDM-ebMS
valide reponsePersonneMorale.entete EDM-ebMS
valide reponseStatutEtudiant.entete EDM-ebMS
valide reponseStatutEtudiantPdf.entete EDM-ebMS
valide reponseDifferee.entete EDM-ebMS
valide erreur.entete EDM-ebMS
valide erreurRequeteInvalide.entete EDM-ebMS
valide erreurCapaciteNonSupportee.entete EDM-ebMS
valide erreurExpiration.entete EDM-ebMS
valide erreurSansIdentifiantDeRequete.entete EDM-ebMS
valide erreurPrevisualisationRequise.entete EDM-ebMS
valide reponseVide.entete EDM-ebMS
valide requeteSeconde.entete EDM-ebMS

# ------------------------------------------------------ validation croisée
# Les messages d'un correspondant, figés sous `spec/fixtures/correspondent/` :
# jugés d'abord seuls et contre leur en-tête, pour qu'une paire ne fasse jamais
# imputer à la France ce qu'eux enfreignent.
valide correspondant.requete EDM-REQ-C
valide correspondant.requete EDM-REQ-S
valide correspondant.requete.entete EDM-ebMS
contreSonEntete REQ correspondant.requete
valide correspondant.erreurPrevisualisationRequise EDM-ERR-C
valide correspondant.erreurPrevisualisationRequise EDM-ERR-S
valide correspondant.erreurPrevisualisationRequise.entete EDM-ebMS
contreSonEntete ERR correspondant.erreurPrevisualisationRequise

# Chaque corps que la France émet, contre son propre en-tête.
contreSonEntete REQ requete requetePersonneMorale requeteClassification requeteTroisClassifications \
  requeteFormatStructure requeteSeconde requetePremiere
contreSonEntete RESP reponse reponsePersonneMorale reponseStatutEtudiant reponseStatutEtudiantPdf reponseDifferee \
  reponseVide recue.reponse recue.reponseVide recue.reponseDifferee
contreSonEntete ERR erreur erreurRequeteInvalide erreurCapaciteNonSupportee erreurExpiration \
  erreurSansIdentifiantDeRequete erreurPrevisualisationRequise recue.erreur recue.erreurRequeteInvalide \
  recue.erreurCapaciteNonSupportee recue.erreurExpiration recue.erreurPrevisualisationRequise

# Ce que la France répond à la requête d'un correspondant, rendu par le code de
# la production d'après cette requête : chaque sorte de réponse de justificatif,
# corps contre corps et en-tête contre en-tête…
for reponse in recue.reponse recue.reponseVide recue.reponseDifferee; do
  croise EDM-REQ_EDM-RESP edm-req=correspondant.requete edm-resp="$reponse"
  croise ebMS-REQ_ebMS-RESP evidence_request_header=correspondant.requete.entete \
    evidence_response_header="$reponse.entete"
done
# … et chaque sorte de réponse d'erreur qui porte un `requestId`, corps contre
# corps : aucun jeu de règles ne confronte l'en-tête d'une erreur à celui de la
# requête refusée.
for erreur in recue.erreur recue.erreurRequeteInvalide recue.erreurCapaciteNonSupportee recue.erreurExpiration \
  recue.erreurPrevisualisationRequise; do
  croise EDM-REQ_EDM-ERR edm-req=correspondant.requete edm-err="$erreur"
done

# La seconde requête d'une prévisualisation, contre la première de la même
# conversation, puis contre l'erreur `PreviewRequired` du correspondant qui l'a
# demandée — où elle se nomme `edm-req`, la règle ne connaissant qu'une requête.
croise EDM-REQ1_EDM-REQ2 edm-req=requetePremiere edm-req2=requeteSeconde
croise ebMS-REQ1_ebMS-REQ2 evidence_request_header1=requetePremiere.entete \
  evidence_request_header2=requeteSeconde.entete
croise EDM-ERR_EDM-REQ2 edm-err=correspondant.erreurPrevisualisationRequise edm-req=requeteSeconde
croise ebMS-ERR_ebMS-REQ2 evidence_error_response_header=correspondant.erreurPrevisualisationRequise.entete \
  evidence_request_header=requeteSeconde.entete

# Les règles FATAL que `EvidenceProvision::RejectMalformedIdentifiers` invoque
# pour refuser de répondre à une requête dont les identifiants ne sont pas des
# UUID. Sans ce spécimen, l'expression rationnelle du dépôt ne s'atteste
# qu'elle-même. `R-EDM-ebMS-037` n'existe pas en 1.2.5, où l'`ExchangeId` n'est
# pas une propriété d'en-tête : seule `-017` y mord.
if [ "$SPECIFICATION_EDM" = 'oots-edm:v1.2' ]; then
  refuse identifiantsMalformes.entete EDM-ebMS R-EDM-ebMS-017

  # Deux distributions demandées, que `R-EDM-REQ-C032` compte « = 1 or = 0 » à
  # l'étiquette 1.2.5 là où la 2.0.1 compte « > 0 » : la requête que la ligne
  # récente admet — un format structuré et une version lisible par un humain à
  # côté, le cas que nomme le 4.5.1 §3.5 — est celle que l'ancienne refuse. Sans
  # ce spécimen, rien ne dit que l'assertion de cette étiquette mord, tous les
  # autres n'en demandant qu'une. Pas de contrepartie en 2.0.1, où la même
  # requête est conforme, et pas d'entête : `EDM-REQ-C` est le seul jeu de règles
  # qui la juge.
  refuse requeteDeuxDistributions EDM-REQ-C R-EDM-REQ-C032
else
  refuse identifiantsMalformes.entete EDM-ebMS R-EDM-ebMS-017,R-EDM-ebMS-037

  # L'entête de la ligne 1.2 confronté à dessein aux règles de la 2.0.1 : deux
  # règles et non une, `R-EDM-ebMS-019` changeant de contexte entre les deux
  # étiquettes — ancrée sur `eb:Property` en 1.2.5, elle l'est sur
  # `eb:MessageProperties` en 2.0.1, où elle compte chacun des quatre noms une
  # fois, qu'un entête à deux propriétés enfreint autant que le comptage de
  # `-018`.
  refuse versionAnterieure.entete EDM-ebMS R-EDM-ebMS-018,R-EDM-ebMS-019
fi

# Code 2 for a rule violation, distinct from the 1 any other failure returns
# (download, compilation): the caller can then retry a network fluke without
# replaying a non-conformance, which will not heal on its own.
if [ "$enEchec" -ne 0 ]; then
  echo
  echo "✗ Des règles Schematron sont violées."
  exit 2
fi

echo
echo "✓ Les messages, leurs entêtes ebMS et les paires d'un même échange sont conformes aux TDD $VERSION_TDD, et les spécimens malformés sont refusés."
