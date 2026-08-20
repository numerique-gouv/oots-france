#!/bin/sh
# Generates the demonstration certificates Domibus needs locally.
#
# The example PMode has Domibus talk to itself (a single party, `blue_gw`, see
# docs/domibus_context.md): the self-signed certificates produced here therefore
# serve both as the gateway's identity (keystore) and as its only trust anchors
# (truststore).
#
# Since Domibus 5.1, security is described by a "profile" rather than by a policy
# file, and the profile imposes the aliases — see docs/domibus_context.md. For
# the blue_gw party and the rsa profile:
#
#   keystore    blue_gw_rsa_sign      private signing key
#               blue_gw_rsa_decrypt   private decryption key
#   truststore  blue_gw_rsa_sign      certificate verifying the peer's signature
#               blue_gw_rsa_encrypt   certificate encrypting towards the peer
#
# The gateway talking to itself, the two truststore certificates are those of the
# two keystore keys.
#
# Usage: scripts/generate_certificates.sh [validity in days; 3650 by default]
#
# The DESTINATION variable writes somewhere other than domibus/keystores — handy
# when that directory belongs to the container and is not reachable.
#
# These certificates are for the development machine only: never reuse them on a
# real environment.

set -e

PARTIE="blue_gw"
PROFIL="rsa"
ALIAS_SIGNATURE="${PARTIE}_${PROFIL}_sign"
ALIAS_DECHIFFREMENT="${PARTIE}_${PROFIL}_decrypt"
ALIAS_CHIFFREMENT="${PARTIE}_${PROFIL}_encrypt"

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
  lanceKeytool -genkeypair -alias "$1" -dname "CN=$PARTIE" \
    -keyalg RSA -keysize 2048 -sigalg SHA256withRSA -validity "$VALIDITE" \
    -keystore "$KEYSTORE" -storetype PKCS12 \
    -storepass "$MOT_DE_PASSE_MAGASINS" -keypass "$MOT_DE_PASSE_MAGASINS"
}

# The certificate is exported from the keystore then imported back into the
# truststore under the alias the security profile expects — the signing one keeps
# its name, the decryption one becomes `_encrypt` on the peer side, since that is
# what the peer encrypts towards us with.
importeCertificat() {
  lanceKeytool -exportcert -alias "$1" -rfc \
    -keystore "$KEYSTORE" -storepass "$MOT_DE_PASSE_MAGASINS" \
    -file "$1.cer"

  lanceKeytool -importcert -noprompt -alias "$2" -file "$1.cer" \
    -keystore "$TRUSTSTORE" -storetype PKCS12 \
    -storepass "$MOT_DE_PASSE_MAGASINS"

  rm "$DESTINATION/$1.cer"
}

genereCle "$ALIAS_SIGNATURE"
genereCle "$ALIAS_DECHIFFREMENT"

importeCertificat "$ALIAS_SIGNATURE" "$ALIAS_SIGNATURE"
importeCertificat "$ALIAS_DECHIFFREMENT" "$ALIAS_CHIFFREMENT"

echo
echo "Certificats générés dans $DESTINATION (valides $VALIDITE jours) :"
echo "  $KEYSTORE   : $ALIAS_SIGNATURE, $ALIAS_DECHIFFREMENT"
echo "  $TRUSTSTORE : $ALIAS_SIGNATURE, $ALIAS_CHIFFREMENT"
