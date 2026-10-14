#!/bin/sh
# Draws, from the highest-numbered key of the keystore — the last one
# scripts/pki/generate_keystore.sh added —, the CSR sent to the eDelivery PKI,
# which answers with our certificate and its chain.
#
# Usage: scripts/pki/generate_csr.sh   (from the directory holding the keystore)

set -e

. "$(dirname "$0")/keystore.sh"

verifiePrerequis
if [ ! -f "$KEYSTORE" ]; then
  echo "❌ $KEYSTORE manque ici : scripts/pki/generate_keystore.sh le crée." >&2
  exit 1
fi
demandeMotDePasse

rang=$(dernierRang)
if [ -z "$rang" ]; then
  echo "❌ $KEYSTORE ne porte aucune clé $PREMIER_ALIAS : scripts/pki/generate_keystore.sh l'y ajoute." >&2
  exit 1
fi
alias=$(nomDAlias "$rang")
csr="$alias.csr"
if [ -e "$csr" ]; then
  echo "❌ $csr existe déjà : le déplacer avant d'en tirer un autre." >&2
  exit 1
fi

keytool -certreq -alias "$alias" -file "$csr" -keystore "$KEYSTORE" -storepass:env MOT_DE_PASSE_KEYSTORE

echo "✅ CSR de la clé $alias écrit dans $csr."
