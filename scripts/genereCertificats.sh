#!/bin/sh
# Génère les certificats de démonstration dont Domibus a besoin en local.
#
# Le PMode d'exemple fait dialoguer Domibus avec lui-même (partie unique
# « blue_gw », voir docs/domibus_context.md) : les certificats auto-signés
# produits ici servent donc à la fois d'identité de la passerelle (keystore) et
# de seules autorités de confiance (truststore).
#
# Depuis Domibus 5.1, la sécurité se décrit par « profil » plutôt que par un
# fichier de politique, et le profil impose les alias — voir
# docs/domibus_context.md. Pour la partie blue_gw et le profil rsa :
#
#   keystore    blue_gw_rsa_sign      clé privée de signature
#               blue_gw_rsa_decrypt   clé privée de déchiffrement
#   truststore  blue_gw_rsa_sign      certificat vérifiant la signature du pair
#               blue_gw_rsa_encrypt   certificat chiffrant à destination du pair
#
# La passerelle se parlant à elle-même, les deux certificats du truststore sont
# ceux des deux clés du keystore.
#
# Usage : scripts/genereCertificats.sh [validité en jours ; 3650 par défaut]
#
# La variable DESTINATION permet d'écrire ailleurs que dans domibus/keystores —
# utile lorsque ce répertoire appartient au conteneur et n'est pas accessible.
#
# Ces certificats sont réservés au poste de développement : ne jamais les
# réutiliser sur un environnement réel.

set -e

PARTIE="blue_gw"
PROFIL="rsa"
ALIAS_SIGNATURE="${PARTIE}_${PROFIL}_sign"
ALIAS_DECHIFFREMENT="${PARTIE}_${PROFIL}_decrypt"
ALIAS_CHIFFREMENT="${PARTIE}_${PROFIL}_encrypt"

# Un seul mot de passe protège les magasins et les clés privées qu'ils
# contiennent : Domibus ne sait pas les dissocier. Les notes de version 5.1.9
# rangent EDELIVERY-13917, « Possibility to upload a keystore with a keystore
# password that is not the same as the password for the private keys », parmi
# les *Known Issues* — c'est une limitation connue, non une fonctionnalité.
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

# keytool n'est pas toujours installé sur la machine hôte ; à défaut, on
# l'exécute depuis une image Docker contenant un JRE.
lanceKeytool() {
  if command -v keytool > /dev/null 2>&1; then
    (cd "$DESTINATION" && keytool "$@")
  else
    docker run --rm --user "$(id -u):$(id -g)" \
      --volume "$DESTINATION:/certificats" --workdir /certificats \
      eclipse-temurin:21-jre keytool "$@"
  fi
}

# PKCS#12, format par défaut de Java depuis la 9 (JEP 229), plutôt que JKS,
# propriétaire et déprécié. Domibus le supporte, mais deux réserves détaillées
# dans docs/versions_domibus.md valent d'être connues : son téléversement ne
# convertit que le truststore — d'où les propriétés imposées au démarrage dans
# docker-compose.yml —, et la documentation signale qu'un PKCS#12 lu sous
# Java 21 peut échouer sur « Could not load key store: keystore password was
# incorrect ».
genereCle() {
  lanceKeytool -genkeypair -alias "$1" -dname "CN=$PARTIE" \
    -keyalg RSA -keysize 2048 -sigalg SHA256withRSA -validity "$VALIDITE" \
    -keystore "$KEYSTORE" -storetype PKCS12 \
    -storepass "$MOT_DE_PASSE_MAGASINS" -keypass "$MOT_DE_PASSE_MAGASINS"
}

# Le certificat est exporté depuis le keystore puis réimporté dans le
# truststore sous l'alias qu'attend le profil de sécurité — celui de la
# signature garde son nom, celui du déchiffrement devient « _encrypt » côté
# pair, puisque c'est avec lui que le pair chiffre à notre intention.
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
