# Sourced by generate_keystore.sh and generate_csr.sh: what both need to find
# their way in the keystore holding the keys of our access point. Each CSR has
# its own key, under OOTS_AP_ACC_FR_001 for the first and OOTS_AP_ACC_FR_001-<n>
# for the next ones, so that a renewal leaves the deployed key untouched.

KEYSTORE=oots_acceptance_keystore.jks
PREMIER_ALIAS=OOTS_AP_ACC_FR_001

verifiePrerequis() {
  if ! command -v keytool > /dev/null 2>&1; then
    echo "❌ keytool manque : il vient avec un JRE, par exemple apt install default-jre-headless." >&2
    exit 1
  fi
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Refus de travailler sur une clé privée dans un dépôt git : se placer là où vit $KEYSTORE, ou l'y créer." >&2
    exit 1
  fi
}

# Asked once and handed to keytool through -storepass:env, which would
# otherwise ask for it at every call.
demandeMotDePasse() {
  MOT_DE_PASSE_KEYSTORE=$(litSansEcho 'Keystore password : ')
  export MOT_DE_PASSE_KEYSTORE
  if [ -f "$KEYSTORE" ]; then
    keytool -list -keystore "$KEYSTORE" -storepass:env MOT_DE_PASSE_KEYSTORE > /dev/null 2>&1 \
      || { echo "❌ $KEYSTORE n'ouvre pas avec ce mot de passe." >&2; exit 1; }
  else
    confirmation=$(litSansEcho 'Keystore password, encore : ')
    [ "$confirmation" = "$MOT_DE_PASSE_KEYSTORE" ] || { echo "❌ Les deux saisies diffèrent." >&2; exit 1; }
  fi
}

# printf rather than echo: dash's echo interprets the backslashes of a password.
litSansEcho() {
  trap 'stty echo 2> /dev/null || true' EXIT
  trap 'exit 130' INT
  printf '%s' "$1" >&2
  stty -echo 2> /dev/null || true
  IFS= read -r saisie || [ -n "$saisie" ] || { printf '\n❌ Saisie interrompue.\n' >&2; exit 1; }
  printf '\n' >&2
  printf '%s\n' "$saisie"
}

# The rank of the highest key present, empty if there is none: 1 for
# OOTS_AP_ACC_FR_001, n for OOTS_AP_ACC_FR_001-<n>. JKS stores its aliases in
# lower case, whatever was typed.
dernierRang() {
  [ -f "$KEYSTORE" ] || return 0
  prefixe=$(printf '%s' "$PREMIER_ALIAS" | tr '[:upper:]' '[:lower:]')
  keytool -list -keystore "$KEYSTORE" -storepass:env MOT_DE_PASSE_KEYSTORE \
    | cut -d, -f1 | tr '[:upper:]' '[:lower:]' \
    | sed -n -e "s/^$prefixe\$/1/p" -e "s/^$prefixe-\([0-9][0-9]*\)\$/\1/p" \
    | sort -n | tail -n 1
}

nomDAlias() {
  if [ "$1" -eq 1 ]; then echo "$PREMIER_ALIAS"; else echo "$PREMIER_ALIAS-$1"; fi
}
