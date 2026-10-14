#!/bin/sh
# Adds to the keystore holding the keys of our access point a new key, first
# step towards a certificate of the eDelivery PKI: scripts/pki/generate_csr.sh
# then draws the CSR from it. The keystore is created on the first run; every
# later run adds a key under an alias of its own and leaves the previous ones
# alone, since the deployed certificate still needs its key until the renewal
# is installed. The script asks for the keystore password, keytool for the
# keypair password; both are needed again by `make update-certifs`.
#
# The keystore is the only copy of the private keys: the PKI never returns them.
# Run this outside the repository, and keep the file and its passwords.
#
# Usage: scripts/pki/generate_keystore.sh   (from the directory that keeps it)

set -e

. "$(dirname "$0")/keystore.sh"

verifiePrerequis
demandeMotDePasse

alias=$(nomDAlias $(($(dernierRang) + 1)))

# 4.7 § 4.2: "RSA certificates should use key sizes larger than 3000 bits".
# 4.7 § 4.3, Access Point signing certificate profile: countryName is the
# country of the registered access point, organizationName the administration
# in charge of it, OU1 "OOTS".
keytool -genkeypair -alias "$alias" -keyalg RSA -keysize 3072 -sigalg SHA256withRSA \
  -dname "CN=$PREMIER_ALIAS, OU=OOTS, O=DINUM, C=FR" -validity 730 \
  -storetype JKS -keystore "$KEYSTORE" -storepass:env MOT_DE_PASSE_KEYSTORE

echo "✅ Clé engendrée sous l'alias $alias dans $KEYSTORE."
