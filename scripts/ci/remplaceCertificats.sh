#!/bin/sh
# Remplace les certificats de démonstration de Domibus par des certificats
# fraîchement générés, une fois la passerelle démarrée.
#
# Ceux que livre l'image ont expiré le 1er décembre 2025 : tant qu'ils sont en
# place, Domibus refuse d'émettre (EBMS_0004) et l'application ne voit qu'un
# délai dépassé. Le remplacement a lieu après le premier démarrage : l'image
# écrase le contenu de ./domibus en s'initialisant, keystores/ compris.
#
# Ce script ne fait que déposer les fichiers ; c'est scripts/configureDomibus.sh
# qui les fait prendre en compte, sans redémarrage. Voir docs/test_e2e.md.
#
# Usage : scripts/ci/remplaceCertificats.sh
#
# Variables reconnues (valeurs par défaut entre parenthèses) :
#   REPERTOIRE_DOMIBUS  répertoire de configuration monté (domibus)
#   MAGASINS_GENERES    où générer les magasins (/tmp/magasins-domibus) ; c'est
#                       de là que configureDomibus.sh lira le truststore

set -e

REPERTOIRE_DOMIBUS="${REPERTOIRE_DOMIBUS:-domibus}"
MAGASINS_GENERES="${MAGASINS_GENERES:-/tmp/magasins-domibus}"

# Les magasins sont générés hors du répertoire de Domibus, qui appartient à
# l'utilisateur du conteneur et n'est ouvert qu'à lui (mode 770). Le truststore
# y reste accessible pour son téléversement.
rm -rf "$MAGASINS_GENERES"
mkdir -p "$MAGASINS_GENERES"
DESTINATION="$MAGASINS_GENERES" scripts/genereCertificats.sh

# La copie se fait donc sous l'identité de root, seule à traverser le
# répertoire, et le propriétaire est aligné sur celui-ci pour que Domibus sache
# lire ses propres magasins (sinon « Could not read truststore from […] »).
sudo cp \
  "$MAGASINS_GENERES/gateway_keystore.jks" \
  "$MAGASINS_GENERES/gateway_truststore.jks" \
  "$REPERTOIRE_DOMIBUS/keystores/"
sudo chown --reference="$REPERTOIRE_DOMIBUS/keystores" \
  "$REPERTOIRE_DOMIBUS/keystores/gateway_keystore.jks" \
  "$REPERTOIRE_DOMIBUS/keystores/gateway_truststore.jks"

echo "Certificats remplacés ; magasins générés dans $MAGASINS_GENERES"
