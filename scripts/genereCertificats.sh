#!/bin/sh
# Génère les certificats de démonstration dont Domibus a besoin en local.
#
# Le PMode d'exemple fait dialoguer Domibus avec lui-même (partie unique
# « blue_gw », voir docs/domibus_context.md) : le certificat auto-signé produit
# ici sert donc à la fois d'identité de la passerelle (keystore) et de seule
# autorité de confiance (truststore).
#
# Usage : scripts/genereCertificats.sh [validité en jours ; 3650 par défaut]
#
# La variable DESTINATION permet d'écrire ailleurs que dans domibus/keystores —
# utile lorsque ce répertoire appartient au conteneur et n'est pas accessible.
#
# Deux fichiers sont écrits dans domibus/keystores/ (répertoire non versionné) :
#   - gateway_keystore.jks   : la clé privée et son certificat, alias blue_gw ;
#   - gateway_truststore.jks : le certificat seul.
#
# Ces certificats sont réservés au poste de développement : ne jamais les
# réutiliser sur un environnement réel.

set -e

ALIAS="blue_gw"
# Doit correspondre aux propriétés domibus.security.*.password
MOT_DE_PASSE="test123"
VALIDITE="${1:-3650}"

DESTINATION="${DESTINATION:-$(git rev-parse --show-toplevel)/domibus/keystores}"
mkdir -p "$DESTINATION"

for fichier in gateway_keystore.jks gateway_truststore.jks; do
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

lanceKeytool -genkeypair -alias "$ALIAS" -dname "CN=$ALIAS" \
  -keyalg RSA -keysize 2048 -sigalg SHA256withRSA -validity "$VALIDITE" \
  -keystore gateway_keystore.jks -storetype JKS \
  -storepass "$MOT_DE_PASSE" -keypass "$MOT_DE_PASSE"

lanceKeytool -exportcert -alias "$ALIAS" -rfc \
  -keystore gateway_keystore.jks -storepass "$MOT_DE_PASSE" \
  -file "$ALIAS.cer"

lanceKeytool -importcert -noprompt -alias "$ALIAS" -file "$ALIAS.cer" \
  -keystore gateway_truststore.jks -storetype JKS \
  -storepass "$MOT_DE_PASSE"

rm "$DESTINATION/$ALIAS.cer"

echo
echo "Certificats générés dans $DESTINATION :"
echo "  gateway_keystore.jks   (alias $ALIAS, valide $VALIDITE jours)"
echo "  gateway_truststore.jks"
echo "Mot de passe des deux magasins : $MOT_DE_PASSE"
