#!/bin/sh
# Loads into the gateway the PMode and the truststore the Technical Support
# Dashboard published for AP_FR_01, as published: converts the truststore to the
# PKCS#12 and the password the gateway reopens it with, lays both down under
# domibus/, uploads them through scripts/configure_domibus.sh, and restarts the
# gateway. The Technical Support Dashboard publishes new ones whenever any
# access point changes, whatever its Member State: this is the command to
# replay then.
#
# The keystore is not touched: it holds the private key of our CSR and the
# certificate the eDelivery PKI returned, built once as docs/deploiement.md says,
# and must already be in place.
#
# Usage: DOMIBUS_MOT_DE_PASSE_ADMIN=… make update-certifs PMODE=<AP_FR_01.xml> TRUSTSTORE=<gateway_truststore.jks>
#   MOT_DE_PASSE_MAGASIN_PUBLIE  password of the published truststore (test123)

set -e

cd "$(dirname "$0")/.."

PMODE="${1:?le PMode du Technical Support Dashboard est à donner : make update-certifs PMODE=… TRUSTSTORE=…}"
TRUSTSTORE="${2:?le magasin de confiance du Technical Support Dashboard est à donner : make update-certifs PMODE=… TRUSTSTORE=…}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:?le mot de passe du compte admin de la console Domibus est à donner}"
MOT_DE_PASSE_MAGASIN_PUBLIE="${MOT_DE_PASSE_MAGASIN_PUBLIE:-test123}"

REPERTOIRE_MAGASINS=domibus/keystores
KEYSTORE="$REPERTOIRE_MAGASINS/gateway_keystore.p12"
TRUSTSTORE_PASSERELLE="$REPERTOIRE_MAGASINS/gateway_truststore.p12"
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

for fichier in "$PMODE" "$TRUSTSTORE"; do
  if [ ! -f "$fichier" ]; then
    echo "❌ Fichier introuvable : $fichier" >&2
    exit 1
  fi
done

# configure_domibus.sh uploads both stores from the same directory: without our
# own key there, it would upload a keystore that cannot sign.
if [ ! -f "$KEYSTORE" ]; then
  echo "❌ $KEYSTORE manque : le keystore de la PKI se construit une fois, avant ce script." >&2
  echo "   docs/deploiement.md, « Raccorder la passerelle à l'acceptation », donne la commande." >&2
  exit 1
fi

PORT_DOMIBUS=$(lisVariable PORT_DOMIBUS .env)
PORT_OOTS_FRANCE=$(lisVariable PORT_OOTS_FRANCE .env)
MOT_DE_PASSE_MAGASINS=$(lisVariable MOT_DE_PASSE_MAGASINS .env)
LOGIN_API_REST=$(lisVariable LOGIN_API_REST .env.oots)
MOT_DE_PASSE_API_REST=$(lisVariable MOT_DE_PASSE_API_REST .env.oots)
LOGIN_NOTIFICATION_DOMIBUS=$(lisVariable LOGIN_NOTIFICATION_DOMIBUS .env.oots)
MOT_DE_PASSE_NOTIFICATION_DOMIBUS=$(lisVariable MOT_DE_PASSE_NOTIFICATION_DOMIBUS .env.oots)
export PORT_DOMIBUS PORT_OOTS_FRANCE MOT_DE_PASSE_MAGASINS LOGIN_API_REST MOT_DE_PASSE_API_REST
export LOGIN_NOTIFICATION_DOMIBUS MOT_DE_PASSE_NOTIFICATION_DOMIBUS DOMIBUS_MOT_DE_PASSE_ADMIN

TEMPORAIRE=$(mktemp -d)
trap 'rm -rf "$TEMPORAIRE"' EXIT

# keytool is not always installed on the host machine; failing that, it is run
# from a Docker image carrying a JRE.
lanceKeytool() {
  if command -v keytool > /dev/null 2>&1; then
    (cd "$TEMPORAIRE" && keytool "$@")
  else
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "$TEMPORAIRE:/magasins" --workdir /magasins \
      eclipse-temurin:21-jre keytool "$@"
  fi
}

# The aliases are kept as the Commission wrote them: the gateway looks a peer's
# certificate up under its party name, see docs/domibus_context.md. Only the
# format and the password change, those the gateway reopens its stores with at
# every start.
echo "→ Conversion du magasin de confiance $TRUSTSTORE"
cp "$TRUSTSTORE" "$TEMPORAIRE/publie.jks"
lanceKeytool -importkeystore -noprompt \
  -srckeystore publie.jks -srcstoretype JKS -srcstorepass "$MOT_DE_PASSE_MAGASIN_PUBLIE" \
  -destkeystore gateway_truststore.p12 -deststoretype PKCS12 \
  -deststorepass "$MOT_DE_PASSE_MAGASINS" > /dev/null
lanceKeytool -list -keystore gateway_truststore.p12 -storepass "$MOT_DE_PASSE_MAGASINS" \
  | grep -c ', trustedCertEntry' | sed 's/^/  certificats : /'

# What is replaced is kept alongside, so that a publication that breaks the
# gateway can be undone by putting the previous files back and replaying
# configure_domibus.sh.
echo "→ Dépôt sous domibus/"
for fichier in "$TRUSTSTORE_PASSERELLE" "$PMODE_PASSERELLE"; do
  if [ -f "$fichier" ]; then
    cp "$fichier" "$fichier.precedent"
  fi
done
cp "$TEMPORAIRE/gateway_truststore.p12" "$TRUSTSTORE_PASSERELLE"
cp "$PMODE" "$PMODE_PASSERELLE"

REPERTOIRE_MAGASINS="$REPERTOIRE_MAGASINS" FICHIER_PMODE="$PMODE_PASSERELLE" \
  scripts/configure_domibus.sh

# The notification rules configure_domibus.sh writes take effect only on a
# restart, and the stores are reread from the disk then.
echo "→ Redémarrage de la passerelle"
docker compose restart domibus
scripts/ci/wait_for_domibus.sh

echo "✅ PMode et magasin de confiance du Technical Support Dashboard chargés ; les précédents sont en *.precedent sous domibus/."
