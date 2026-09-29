#!/bin/sh
# Loads into the gateway the PMode and the truststore the Technical Support
# Dashboard published for AP_FR_01, as published: converts the truststore to the
# PKCS#12 and the password the gateway reopens it with, lays both down under
# domibus/, uploads them through scripts/configure_domibus.sh, and restarts the
# gateway. The Technical Support Dashboard publishes new ones whenever any
# access point changes, whatever its Member State: this is the command to
# replay then.
#
# Given our private key — in the keystore keytool created it in, or as a PEM —,
# the certificate the eDelivery PKI returned for it and that certificate's
# chain, it rebuilds the keystore first: the first connection,
# and every renewal of our certificate. Without them it keeps the keystore in
# place, and refuses to run if there is none.
#
# Usage: make update-certifs   (asks what to update, then for each file)
#        DOMIBUS_MOT_DE_PASSE_ADMIN=… make update-certifs PMODE=<AP_FR_01.xml> TRUSTSTORE=<gateway_truststore.jks> \
#          [CLE=<oots_acceptance_keystore.jks> CERTIFICAT=<OOTS_AP_ACC_FR_001.pem> CHAINE=<OOTS_AP_ACC_FR_001-bundle.pem>]
#   MOT_DE_PASSE_TRUSTSTORE_PUBLIE  password of the published truststore (test123)
#   MOT_DE_PASSE_KEYSTORE_CLE       keystore password of the keystore CLE names, when it is one
#   MOT_DE_PASSE_KEYPAIR            keypair password of the key inside it, when it differs
#   ALIAS_CLE                       the key's alias, when that keystore holds several

set -e

ORIGINE=$(pwd)
cd "$(dirname "$0")/.."

# Private from the start: our private key, taken out of its keystore, lands
# here, and must neither be readable by others nor outlive the script.
umask 077
TEMPORAIRE=$(mktemp -d)
trap 'rm -rf "$TEMPORAIRE"' EXIT

PMODE="${1:-}"
TRUSTSTORE="${2:-}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-}"
MOT_DE_PASSE_TRUSTSTORE_PUBLIE="${MOT_DE_PASSE_TRUSTSTORE_PUBLIE:-test123}"
CLE="${CLE:-}"
MOT_DE_PASSE_KEYSTORE_CLE="${MOT_DE_PASSE_KEYSTORE_CLE:-}"
MOT_DE_PASSE_KEYPAIR="${MOT_DE_PASSE_KEYPAIR:-}"
ALIAS_CLE="${ALIAS_CLE:-}"
CERTIFICAT="${CERTIFICAT:-}"
CHAINE="${CHAINE:-}"
PARTIE="AP_FR_01"
NOUVEAU_KEYSTORE=""

# What `read` returns is taken literally: neither `~` nor a path relative to
# where the operator stood survives the `cd` above unless resolved here.
chemin() {
  case "$1" in
    "") echo "" ;;
    "~/"*) echo "$HOME/${1#\~/}" ;;
    /*) echo "$1" ;;
    *) echo "$ORIGINE/$1" ;;
  esac
}

estPem() {
  head -n 1 "$1" 2> /dev/null | grep -q -- '-----BEGIN'
}

demande() {
  printf '%s%s : ' "$1" "${2:+ [$2]}" >&2
  read -r reponse
  echo "${reponse:-$2}"
}

demandeSecret() {
  printf '%s : ' "$1" >&2
  trap 'stty echo; exit 1' INT
  stty -echo
  read -r reponse
  stty echo
  trap - INT
  echo >&2
  echo "$reponse"
}

if [ -z "$PMODE" ] || [ -z "$TRUSTSTORE" ]; then
  if [ ! -t 0 ]; then
    echo "❌ Sans terminal, tout se donne à la commande :" >&2
    echo "   DOMIBUS_MOT_DE_PASSE_ADMIN=… make update-certifs PMODE=<AP_FR_01.xml> TRUSTSTORE=<gateway_truststore.jks> \\" >&2
    echo "     [CLE=<oots_acceptance_keystore.jks> CERTIFICAT=<OOTS_AP_ACC_FR_001.pem> CHAINE=<OOTS_AP_ACC_FR_001-bundle.pem>]" >&2
    exit 1
  fi

  cat >&2 <<'QUESTION'
Que faut-il mettre à jour ?

  1. Le PMode et le truststore, que le Technical Support Dashboard
     vient de republier. C'est le cas courant : il les régénère dès qu'un point
     d'accès du réseau change, quel que soit l'État membre.

  2. Notre certificat aussi — premier raccordement, ou renouvellement du
     certificat que la PKI eDelivery a délivré. Le keystore est reconstruit avec
     notre clé privée et ce certificat, puis le PMode et le truststore
     sont chargés comme en 1.

QUESTION
  case "$(demande "Choix" 1)" in
    1) ;;
    2) NOUVEAU_KEYSTORE=oui ;;
    *) echo "❌ Répondre 1 ou 2." >&2; exit 1 ;;
  esac

  echo >&2
  echo "Fichiers publiés par le Technical Support Dashboard :" >&2
  PMODE=$(chemin "$(demande "  PMode" AP_FR_01.xml)")
  TRUSTSTORE=$(chemin "$(demande "  Truststore" gateway_truststore.jks)")
  if [ -n "$NOUVEAU_KEYSTORE" ]; then
    echo "Notre clé privée : le keystore où keytool l'a créée avant le CSR (.jks, .p12), ou son fichier PEM :" >&2
    CLE=$(chemin "$(demande "  Clé privée")")
    if ! estPem "$CLE" && [ -z "$MOT_DE_PASSE_KEYSTORE_CLE" ]; then
      MOT_DE_PASSE_KEYSTORE_CLE=$(demandeSecret "  Keystore password, le mot de passe de ce keystore")
      MOT_DE_PASSE_KEYPAIR=$(demandeSecret "  Keypair password, le mot de passe de la clé (Entrée s'il est le même)")
    fi
    echo "Le certificat que la PKI a rendu pour elle :" >&2
    CERTIFICAT=$(chemin "$(demande "  Certificat rendu par la PKI" OOTS_AP_ACC_FR_001.pem)")
    CHAINE=$(chemin "$(demande "  Sa chaîne" OOTS_AP_ACC_FR_001-bundle.pem)")
  fi
  if [ -z "$DOMIBUS_MOT_DE_PASSE_ADMIN" ]; then
    DOMIBUS_MOT_DE_PASSE_ADMIN=$(demandeSecret "Mot de passe du compte admin de la console Domibus")
  fi
  echo >&2
else
  PMODE=$(chemin "$PMODE")
  TRUSTSTORE=$(chemin "$TRUSTSTORE")
  CLE=$(chemin "$CLE")
  CERTIFICAT=$(chemin "$CERTIFICAT")
  CHAINE=$(chemin "$CHAINE")
fi

if [ -z "$DOMIBUS_MOT_DE_PASSE_ADMIN" ]; then
  echo "❌ Le mot de passe du compte admin de la console Domibus est à donner : DOMIBUS_MOT_DE_PASSE_ADMIN=…" >&2
  exit 1
fi

REPERTOIRE_KEYSTORE_TRUSTSTORE=domibus/keystores
KEYSTORE="$REPERTOIRE_KEYSTORE_TRUSTSTORE/gateway_keystore.p12"
TRUSTSTORE_PASSERELLE="$REPERTOIRE_KEYSTORE_TRUSTSTORE/gateway_truststore.p12"
PMODE_PASSERELLE="domibus/$(basename "$PMODE")"

# The values of a .env* cannot be sourced with `.`: they carry JSON braces and
# `&`. The ones the rest needs are taken out of it.
lisVariable() {
  valeur=$(sed -n "s/^$1=//p" "$2" | head -n 1)
  if [ -z "$valeur" ]; then
    echo "❌ $1 est absente de $2 : compléter ce fichier." >&2
    exit 1
  fi
  echo "$valeur"
}

if [ -n "$NOUVEAU_KEYSTORE$CLE$CERTIFICAT$CHAINE" ]; then
  if [ -z "$CLE" ] || [ -z "$CERTIFICAT" ] || [ -z "$CHAINE" ]; then
    echo "❌ CLE, CERTIFICAT et CHAINE se donnent ensemble, ou pas du tout." >&2
    exit 1
  fi
  NOUVEAU_KEYSTORE=oui
fi

for fichier in "$PMODE" "$TRUSTSTORE" ${NOUVEAU_KEYSTORE:+"$CLE" "$CERTIFICAT" "$CHAINE"}; do
  if [ ! -f "$fichier" ]; then
    echo "❌ Fichier introuvable : $fichier" >&2
    exit 1
  fi
done

# configure_domibus.sh uploads both stores from the same directory: without our
# own key there, it would upload a keystore that cannot sign.
if [ -z "$NOUVEAU_KEYSTORE" ] && [ ! -f "$KEYSTORE" ]; then
  echo "❌ $KEYSTORE manque : la première fois, c'est le choix 2, qui installe aussi notre certificat —" >&2
  echo "   ou, à la commande : CLE=<oots_acceptance_keystore.jks> CERTIFICAT=<OOTS_AP_ACC_FR_001.pem> CHAINE=<OOTS_AP_ACC_FR_001-bundle.pem>" >&2
  exit 1
fi

PORT_DOMIBUS=$(lisVariable PORT_DOMIBUS .env)
PORT_OOTS_FRANCE=$(lisVariable PORT_OOTS_FRANCE .env)
MOT_DE_PASSE_KEYSTORE_TRUSTSTORE=$(lisVariable MOT_DE_PASSE_KEYSTORE_TRUSTSTORE .env)
LOGIN_API_REST=$(lisVariable LOGIN_API_REST .env.oots)
MOT_DE_PASSE_API_REST=$(lisVariable MOT_DE_PASSE_API_REST .env.oots)
LOGIN_NOTIFICATION_DOMIBUS=$(lisVariable LOGIN_NOTIFICATION_DOMIBUS .env.oots)
MOT_DE_PASSE_NOTIFICATION_DOMIBUS=$(lisVariable MOT_DE_PASSE_NOTIFICATION_DOMIBUS .env.oots)
export PORT_DOMIBUS PORT_OOTS_FRANCE MOT_DE_PASSE_KEYSTORE_TRUSTSTORE LOGIN_API_REST MOT_DE_PASSE_API_REST
export LOGIN_NOTIFICATION_DOMIBUS MOT_DE_PASSE_NOTIFICATION_DOMIBUS DOMIBUS_MOT_DE_PASSE_ADMIN

# keytool is not always installed on the host machine; failing that, it is run
# from a Docker image carrying a JRE.
lanceKeytool() {
  if command -v keytool > /dev/null 2>&1; then
    (cd "$TEMPORAIRE" && keytool "$@")
  else
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "$TEMPORAIRE:/stores" --workdir /stores \
      eclipse-temurin:21-jre keytool "$@"
  fi
}

# keytool creates the key inside a keystore, and the CSR from it: the key is
# taken out of there, under a password of the script's own, as the PEM openssl
# works with.
extraisCle() {
  cp "$CLE" "$TEMPORAIRE/source"
  if ! lanceKeytool -list -keystore source -storepass "$MOT_DE_PASSE_KEYSTORE_CLE" \
    > "$TEMPORAIRE/liste" 2>&1; then
    echo "❌ $CLE ne s'ouvre pas — keystore password erroné ? keytool a répondu :" >&2
    sed 's/^/   /' "$TEMPORAIRE/liste" >&2
    exit 1
  fi
  if [ -z "$ALIAS_CLE" ]; then
    ALIAS_CLE=$(sed -n 's/^\([^,]*\), .*PrivateKeyEntry.*/\1/p' "$TEMPORAIRE/liste")
    case "$(echo "$ALIAS_CLE" | grep -c .)" in
      1) ;;
      0) echo "❌ $CLE ne contient aucune clé privée." >&2; exit 1 ;;
      *) echo "❌ $CLE contient plusieurs clés privées, $(echo $ALIAS_CLE) : désigner la bonne par ALIAS_CLE=…" >&2; exit 1 ;;
    esac
  fi
  if ! lanceKeytool -importkeystore -noprompt \
    -srckeystore source -srcstorepass "$MOT_DE_PASSE_KEYSTORE_CLE" \
    -srcalias "$ALIAS_CLE" -srckeypass "${MOT_DE_PASSE_KEYPAIR:-$MOT_DE_PASSE_KEYSTORE_CLE}" \
    -destkeystore cle.p12 -deststoretype PKCS12 \
    -deststorepass extraction -destkeypass extraction > "$TEMPORAIRE/extraction" 2>&1; then
    echo "❌ La clé « $ALIAS_CLE » ne s'ouvre pas — keypair password erroné ? keytool a répondu :" >&2
    sed 's/^/   /' "$TEMPORAIRE/extraction" >&2
    exit 1
  fi
  if ! openssl pkcs12 -in "$TEMPORAIRE/cle.p12" -passin pass:extraction -nocerts -nodes \
    -out "$TEMPORAIRE/cle.pem" 2> "$TEMPORAIRE/conversion"; then
    echo "❌ La clé « $ALIAS_CLE » ne se convertit pas en PEM ; openssl a répondu :" >&2
    sed 's/^/   /' "$TEMPORAIRE/conversion" >&2
    exit 1
  fi
  echo "  clé « $ALIAS_CLE » lue dans $CLE"
  CLE="$TEMPORAIRE/cle.pem"
}

# Built aside and checked before anything under domibus/ is touched: a key that
# is not the certificate's would sign what no correspondent can verify, with no
# symptom but messages never acknowledged. The alias is the party's name, the
# one docker-compose.yml gives domibus.security.key.private.alias.
if [ -n "$NOUVEAU_KEYSTORE" ]; then
  echo "→ Keystore : $CLE et $CERTIFICAT, sous l'alias $PARTIE"
  if ! estPem "$CLE"; then
    if [ -z "$MOT_DE_PASSE_KEYSTORE_CLE" ]; then
      echo "❌ $CLE est un keystore : donner son keystore password par MOT_DE_PASSE_KEYSTORE_CLE=…" >&2
      exit 1
    fi
    extraisCle
  fi
  if [ "$(openssl x509 -in "$CERTIFICAT" -noout -pubkey)" != "$(openssl pkey -in "$CLE" -pubout)" ]; then
    echo "❌ La clé donnée n'est pas celle de $CERTIFICAT : chercher celle qui a signé le CSR." >&2
    exit 1
  fi
  openssl pkcs12 -export -name "$PARTIE" -inkey "$CLE" \
    -in "$CERTIFICAT" -certfile "$CHAINE" \
    -out "$TEMPORAIRE/gateway_keystore.p12" -passout "pass:$MOT_DE_PASSE_KEYSTORE_TRUSTSTORE"
  openssl x509 -in "$CERTIFICAT" -noout -subject -enddate | sed 's/^/  /'
fi

# The aliases are kept as the Commission wrote them: the gateway looks a peer's
# certificate up under its party name, see docs/domibus_context.md. Only the
# format and the password change, those the gateway reopens its stores with at
# every start.
echo "→ Conversion du truststore $TRUSTSTORE"
cp "$TRUSTSTORE" "$TEMPORAIRE/publie.jks"
lanceKeytool -importkeystore -noprompt \
  -srckeystore publie.jks -srcstoretype JKS -srcstorepass "$MOT_DE_PASSE_TRUSTSTORE_PUBLIE" \
  -destkeystore gateway_truststore.p12 -deststoretype PKCS12 \
  -deststorepass "$MOT_DE_PASSE_KEYSTORE_TRUSTSTORE" > /dev/null
lanceKeytool -list -keystore gateway_truststore.p12 -storepass "$MOT_DE_PASSE_KEYSTORE_TRUSTSTORE" \
  | grep -c ', trustedCertEntry' | sed 's/^/  certificats : /'

# What is replaced is kept alongside, so that a publication that breaks the
# gateway can be undone by putting the previous files back and replaying
# configure_domibus.sh.
echo "→ Dépôt sous domibus/"
for fichier in "$TRUSTSTORE_PASSERELLE" "$PMODE_PASSERELLE" ${NOUVEAU_KEYSTORE:+"$KEYSTORE"}; do
  if [ -f "$fichier" ]; then
    cp "$fichier" "$fichier.precedent"
  fi
done
cp "$TEMPORAIRE/gateway_truststore.p12" "$TRUSTSTORE_PASSERELLE"
if [ -n "$NOUVEAU_KEYSTORE" ]; then
  cp "$TEMPORAIRE/gateway_keystore.p12" "$KEYSTORE"
fi
cp "$PMODE" "$PMODE_PASSERELLE"

REPERTOIRE_KEYSTORE_TRUSTSTORE="$REPERTOIRE_KEYSTORE_TRUSTSTORE" FICHIER_PMODE="$PMODE_PASSERELLE" \
  scripts/configure_domibus.sh

# The notification rules configure_domibus.sh writes take effect only on a
# restart, and the stores are reread from the disk then.
echo "→ Redémarrage de la passerelle"
docker compose restart domibus
scripts/ci/wait_for_domibus.sh

echo "✅ PMode et truststore du Technical Support Dashboard chargés${NOUVEAU_KEYSTORE:+, keystore reconstruit} ; les précédents sont en *.precedent sous domibus/."
