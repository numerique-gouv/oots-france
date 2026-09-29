#!/bin/sh
# Creates the keystore holding the private key of our access point, first step
# towards the certificate of the eDelivery PKI: scripts/pki/generate_csr.sh then
# draws the CSR from it. keytool asks for the keystore password, then the keypair
# password; both are needed again by `make update-certifs`.
#
# The keystore is the only copy of the private key: the PKI never returns it.
# Run this outside the repository, and keep the file and its two passwords.
#
# Usage: scripts/pki/generate_keystore.sh   (from the directory that will keep it)

set -e

if ! command -v keytool > /dev/null 2>&1; then
  echo "❌ keytool manque : il vient avec un JRE, par exemple apt install default-jre-headless." >&2
  exit 1
fi
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "❌ Refus de créer une clé privée dans un dépôt git : se placer ailleurs, par exemple ~/certif_stuff." >&2
  exit 1
fi

keytool -genkeypair -alias OOTS_AP_ACC_FR_001 -keyalg RSA -keysize 2048 -sigalg SHA256withRSA \
  -dname "cn=OOTS_AP_ACC_FR_001, c=BE, o=DINUM, ou=OOTS" -validity 730 \
  -storetype JKS -keystore oots_acceptance_keystore.jks
