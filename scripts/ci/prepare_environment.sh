#!/bin/sh
# Writes the .env* files docker compose expects, with throwaway values meant for
# continuous integration (see docs/test_e2e.md) and for the local install, which
# scripts/setup.sh layers on top.
#
# No value here is a secret: the database, the gateway and the decryption key are
# recreated on every run and destroyed with the runner.
#
# Usage: scripts/ci/prepare_environment.sh
#
# Recognised variables:
#   FORCER=1  overwrites existing files (see the guard below)

set -e

FICHIERS=".env .env.domibus .env.oots .env.postgres"

# These files are not versioned: overwriting them destroys a local configuration
# nothing can recover. On a runner they do not exist and the script writes
# without asking; elsewhere it stops, short of an explicit FORCER=1.
EXISTANTS=""
for fichier in $FICHIERS; do
  [ -e "$fichier" ] && EXISTANTS="$EXISTANTS $fichier"
done

if [ -n "$EXISTANTS" ] && [ "$FORCER" != "1" ]; then
  echo "❌ Refus d'écraser une configuration existante :$EXISTANTS" >&2
  echo "   Ces fichiers ne sont pas versionnés : leur contenu serait perdu." >&2
  echo "   Relancer avec FORCER=1 pour les remplacer malgré tout." >&2
  exit 1
fi

# These credentials must be the same as those passed to
# scripts/configure_domibus.sh: this is the account the script creates in Domibus
# and the one the application authenticates with.
#
# Domibus requires the password to be 16 to 32 characters, with an upper case, a
# lower case, a digit and a special character: any shorter and it is refused at
# creation.
LOGIN_API_REST="${LOGIN_API_REST:-oots_ci}"
MOT_DE_PASSE_API_REST="${MOT_DE_PASSE_API_REST:-Ci-OotsFrance-2026!}"

# This password protects the certificate stores. The gateway reads it from .env,
# the scripts from the environment: taking it from here guarantees both see the
# same value, as for the credentials above.
MOT_DE_PASSE_MAGASINS="${MOT_DE_PASSE_MAGASINS:-test123}"

# The credentials Domibus will put on its notifications towards us. They must be
# the same here and in `wsplugin.push.auth.*` on the gateway side, which
# scripts/configure_domibus.sh fills in.
LOGIN_NOTIFICATION_DOMIBUS="${LOGIN_NOTIFICATION_DOMIBUS:-domibus_push}"
MOT_DE_PASSE_NOTIFICATION_DOMIBUS="${MOT_DE_PASSE_NOTIFICATION_DOMIBUS:-Push-OotsFrance-2026!}"

# Unquoted heredoc: the values above must be substituted.
cat > .env <<FIN
PORT_DOMIBUS=8180
PORT_OOTS_FRANCE=3000
PORT_POSTGRES=5433
MOT_DE_PASSE_MAGASINS=$MOT_DE_PASSE_MAGASINS
FIN

cat > .env.domibus <<'FIN'
MYSQL_ROOT_PASSWORD=root_ci
MYSQL_DATABASE=domibus
MYSQL_USER=domibus
MYSQL_PASSWORD=domibus_ci
DB_USER=domibus
DB_PASS=domibus_ci
FIN

# The continuous integration runner installs Ruby for itself; a development
# machine has only Git and Docker as prerequisites, hence the fallback on the
# official image. The version is read from .ruby-version rather than written
# here: the repository already pins the same value in several places, and wants
# no more of them.
executeRuby() {
  if command -v ruby >/dev/null 2>&1; then
    ruby "$@"
    return
  fi

  # Without this guard, a missing file would give the tag `ruby:-slim` and a
  # Docker reference error, with no visible relation to its cause.
  if [ ! -f .ruby-version ]; then
    echo "❌ .ruby-version introuvable : lancer ce script depuis la racine du dépôt." >&2
    exit 1
  fi

  docker run --rm "ruby:$(cat .ruby-version)-slim" ruby "$@"
}

# The private decryption key is generated on the fly: nothing to version, and
# every run starts from a fresh secret. Ruby's standard library is enough, with
# no gem.
#
# RSA-OAEP-256, and not ECDH-ES: it is the only key management algorithm the Ruby
# gems actually handle — the one `apistration` already uses. Nothing on the OOTS
# side requires it: this token is the interface between a French procedure and
# this component, which no TDD chapter constrains. The route that publishes the
# key does so by subtracting the secret components, so the key type stays free
# and the choice reversible.
CLE_PRIVEE_JWK_EN_BASE64=$(executeRuby -ropenssl -rjson -rbase64 -e '
cle = OpenSSL::PKey::RSA.generate(2048)
b64 = ->(bn) { Base64.urlsafe_encode64(bn.to_s(2), padding: false) }

jwk = {
  kty: "RSA", alg: "RSA-OAEP-256", use: "enc",
  n: b64[cle.n], e: b64[cle.e], d: b64[cle.d],
  p: b64[cle.p], q: b64[cle.q],
  dp: b64[cle.dmp1], dq: b64[cle.dmq1], qi: b64[cle.iqmp],
}

puts Base64.strict_encode64(JSON.generate(jwk))
')

# Output that is truncated or polluted would be copied into .env.oots as it is.
# `Settings.verify!` would not catch it there: it only rejects empty values, and
# this one is not empty. The failure would therefore surface only at the first
# token decryption, far from here. The check stays on `base64` alone: the machine
# that needed the Docker fallback above still has no Ruby to read back what it
# produced.
#
# The decoding is taken out of the pipe so that its exit code is the one tested:
# in a pipe only the last one counts, and `base64 -d` writes to stdout everything
# it managed to decode before failing.
CLE_JWK_DECODEE=$(echo "$CLE_PRIVEE_JWK_EN_BASE64" | base64 -d 2>/dev/null) || {
  echo "❌ La clé JWK produite n'est pas du base64 valide." >&2
  exit 1
}

# `qi` is the last field the generator writes, and `}` closes the object:
# looking for `kty`, which comes first, would let through a key truncated right
# after it — and so stripped of all the cryptographic material.
case "$CLE_JWK_DECODEE" in
  *'"qi"'*'}') ;;
  *)
    echo "❌ La clé JWK produite est incomplète." >&2
    exit 1
    ;;
esac

# The French provider keeps its real identity rather than a test name: that
# identity is copied into the `ErrorProvider` of the reference messages in
# spec/fixtures/, and `spec/support/test_environment.rb` only sets it with `||=`.
# A test name here would reach the container through `env_file` and turn the unit
# suite red, though nothing in it had changed.
#
# The two directory URLs designate the fake directory the end-to-end suite raises
# itself, and the trust store the certificate it generates at start-up: that is
# what makes `make e2e` reproducible, where the central directories would demand
# a registration of France nobody here controls. Emptying them and putting
# config/certificats/services_communs_acc.pem back wires the stack onto
# acceptance — see docs/test_e2e.md.
cat > .env.oots <<FIN
AVEC_REQUETE_PIECE_JUSTIFICATIVE=true
CLE_PRIVEE_JWK_EN_BASE64=$CLE_PRIVEE_JWK_EN_BASE64
DONNEES_REQUETEURS={"00000000000002":{"nom":"Requêteur de test","url":"http://web:4000"}}
IDENTIFIANT_FOURNISSEUR_FRANCAIS=00000000000001
NOM_FOURNISSEUR_FRANCAIS=Direction interministérielle du numérique
URL_OOTS_FRANCE=http://localhost:3000

CERTIFICATS_SERVICES_COMMUNS=tmp/annuaires_simules.pem
DELAI_MAX_SERVICES_COMMUNS=10000
DUREE_CACHE_SERVICES_COMMUNS=3600
ENVIRONNEMENT_SERVICES_COMMUNS=acc
PAYS_SERVICES_COMMUNS=FR
URL_BASE_EVIDENCE_BROKER=http://web:4001/eb
URL_BASE_DATA_SERVICE_DIRECTORY=http://web:4001/dsd

DELAI_MAX_ATTENTE_DOMIBUS=30000
IDENTIFIANT_EXPEDITEUR_DOMIBUS=AP_FR_01
SUFFIXE_IDENTIFIANTS_DOMIBUS=oots.eu
TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS=urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR
URL_BASE_DOMIBUS=http://domibus:8080/domibus

LOGIN_API_REST=$LOGIN_API_REST
MOT_DE_PASSE_API_REST=$MOT_DE_PASSE_API_REST
LOGIN_NOTIFICATION_DOMIBUS=$LOGIN_NOTIFICATION_DOMIBUS
MOT_DE_PASSE_NOTIFICATION_DOMIBUS=$MOT_DE_PASSE_NOTIFICATION_DOMIBUS

DELAI_EXPIRATION_REQUETEUR_MINUTES=6
DELAI_EXPIRATION_FOURNISSEUR_MINUTES=5

CLE_CHIFFREMENT_JOURNAL=journal_cle_de_chiffrement_pour_integration_continue
CLE_CHIFFREMENT_DETERMINISTE_JOURNAL=journal_cle_deterministe_pour_integration_continue
SEL_DERIVATION_CLES_JOURNAL=journal_sel_de_derivation_pour_integration_continue
DUREE_RETENTION_JOURNAL_MOIS=12

HOTE_BASE_DE_DONNEES=postgres
PORT_BASE_DE_DONNEES=5432
UTILISATEUR_BASE_DE_DONNEES=oots_france
MOT_DE_PASSE_BASE_DE_DONNEES=oots_france
NOM_BASE_DE_DONNEES=oots_france
FIN

# The same values, under the names the PostgreSQL image expects. They must stay
# in step with those above, as .env.domibus already requires between MYSQL_USER
# and DB_USER.
cat > .env.postgres <<'FIN'
POSTGRES_USER=oots_france
POSTGRES_PASSWORD=oots_france
POSTGRES_DB=oots_france
FIN

# The templates declare the contract: every variable one of them names must be
# written here. Without this check, forgetting a newly mandatory variable shows
# only when the stack starts, two steps further on, as a wait that expires with
# nothing to say.
ERREURS=""
signale() {
  ERREURS="${ERREURS:+$ERREURS
}$1"
}

for fichier in $FICHIERS; do
  # A missing template would make the `sed` below fail inside a command
  # substitution, whose status the shell does not look at: the loop would run
  # empty and the check would pass, restoring the very silent wait it exists to
  # prevent.
  if [ ! -r "$fichier.template" ]; then
    signale "❌ $fichier.template introuvable : le contrat ne peut pas être vérifié."
    continue
  fi

  MANQUANTES=""
  for variable in $(sed -n 's/^\([A-Z_][A-Z_0-9]*\)=.*/\1/p' "$fichier.template"); do
    grep -q "^$variable=" "$fichier" || MANQUANTES="$MANQUANTES $variable"
  done

  if [ -n "$MANQUANTES" ]; then
    signale "❌ Variables déclarées par $fichier.template et absentes de $fichier :$MANQUANTES"
  fi
done

# All four files are reported at once: exiting on the first offender would mask
# the ones after it, and cost as many round trips as there are files.
if [ -n "$ERREURS" ]; then
  echo "$ERREURS" >&2
  echo "   Compléter scripts/ci/prepare_environment.sh." >&2
  exit 1
fi

echo "Fichiers .env, .env.domibus, .env.oots et .env.postgres écrits."
