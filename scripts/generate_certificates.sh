#!/bin/sh
# Generates the demonstration certificates Domibus needs locally.
#
# The example PMode has Domibus talk to itself (a single party, `AP_FR_01`, see
# docs/domibus_context.md): the self-signed certificate produced here therefore
# serves both as the gateway's identity (keystore) and as its only trust anchor
# (truststore).
#
# One alias per party, named after the party, and no suffix: the gateway runs
# without Domibus's security profiles — docs/domibus_context.md says why — so it
# signs and decrypts with the one key `domibus.security.key.private.alias` names,
# and looks a peer's certificate up under the peer's party name. The truststore
# the Commission publishes follows the same convention.
#
#   keystore    AP_FR_01   private key, signing and decryption alike
#   truststore  AP_FR_01   its certificate, the gateway being its own peer
#
# Usage: scripts/generate_certificates.sh [validity in days; 3650 by default]
#
# The DESTINATION variable writes somewhere other than domibus/keystores — handy
# when that directory belongs to the container and is not reachable.
#
# These certificates are for the development machine only: never reuse them on a
# real environment.

set -e

PARTIE="AP_FR_01"

# One password protects the stores and the private keys they hold: Domibus
# cannot tell them apart. The 5.1.9 release notes file EDELIVERY-13917,
# "Possibility to upload a keystore with a keystore password that is not the same
# as the password for the private keys", under *Known Issues* — a known
# limitation, not a feature.
MOT_DE_PASSE_MAGASINS="${MOT_DE_PASSE_MAGASINS:?doit être renseigné, et correspondre à celui de .env}"
VALIDITE="${1:-3650}"

KEYSTORE="gateway_keystore.p12"
TRUSTSTORE="gateway_truststore.p12"

DESTINATION="${DESTINATION:-$(git rev-parse --show-toplevel)/domibus/keystores}"
mkdir -p "$DESTINATION"

for fichier in "$KEYSTORE" "$TRUSTSTORE"; do
  if [ -e "$DESTINATION/$fichier" ]; then
    echo "Erreur : $DESTINATION/$fichier existe déjà." >&2
    echo "Supprimer les fichiers existants avant de régénérer." >&2
    exit 1
  fi
done

# keytool is not always installed on the host machine; failing that, it is run
# from a Docker image carrying a JRE.
lanceKeytool() {
  if command -v keytool > /dev/null 2>&1; then
    (cd "$DESTINATION" && keytool "$@")
  else
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "$DESTINATION:/certificats" --workdir /certificats \
      eclipse-temurin:21-jre keytool "$@"
  fi
}

# PKCS#12, Java's default format since 9 (JEP 229), rather than JKS, which is
# proprietary and deprecated. Domibus supports it, but two reservations detailed
# in docs/versions_domibus.md are worth knowing: uploading it converts the
# truststore only — hence the properties forced at start-up in
# docker-compose.yml — and the documentation reports that a PKCS#12 read under
# Java 21 can fail on "Could not load key store: keystore password was
# incorrect".
genereCle() {
  lanceKeytool -genkeypair -alias "$PARTIE" -dname "CN=$PARTIE" \
    -keyalg RSA -keysize 2048 -sigalg SHA256withRSA -validity "$VALIDITE" \
    -keystore "$KEYSTORE" -storetype PKCS12 \
    -storepass "$MOT_DE_PASSE_MAGASINS" -keypass "$MOT_DE_PASSE_MAGASINS"
}

# The certificate is exported from the keystore then imported into the
# truststore under the same alias: the peer the gateway trusts is itself.
importeCertificat() {
  lanceKeytool -exportcert -alias "$PARTIE" -rfc \
    -keystore "$KEYSTORE" -storepass "$MOT_DE_PASSE_MAGASINS" \
    -file "$PARTIE.cer"

  lanceKeytool -importcert -noprompt -alias "$PARTIE" -file "$PARTIE.cer" \
    -keystore "$TRUSTSTORE" -storetype PKCS12 \
    -storepass "$MOT_DE_PASSE_MAGASINS"

  rm "$DESTINATION/$PARTIE.cer"
}

genereCle
importeCertificat

echo
echo "Certificats générés dans $DESTINATION (valides $VALIDITE jours) :"
echo "  $KEYSTORE   : $PARTIE"
echo "  $TRUSTSTORE : $PARTIE"
