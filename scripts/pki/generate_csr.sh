#!/bin/sh
# Draws from the keystore scripts/pki/generate_keystore.sh created the CSR sent
# to the eDelivery PKI, which answers with our certificate and its chain.
#
# Usage: scripts/pki/generate_csr.sh   (from the directory holding the keystore)

set -e

if ! command -v keytool > /dev/null 2>&1; then
  echo "❌ keytool manque : il vient avec un JRE, par exemple apt install default-jre-headless." >&2
  exit 1
fi
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "❌ Refus de travailler sur une clé privée dans un dépôt git : se placer là où vit oots_acceptance_keystore.jks." >&2
  exit 1
fi

keytool -certreq -alias OOTS_AP_ACC_FR_001 -file OOTS_AP_ACC_FR_001.csr -keystore oots_acceptance_keystore.jks
