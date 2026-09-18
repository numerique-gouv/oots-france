#!/bin/sh
# Writes the .env* files docker compose expects, by deriving each one from its
# template: the templates carry both the contract — which variables exist — and
# the value each takes on a development machine (see docs/test_e2e.md and the
# local install, which scripts/setup.sh layers on top).
#
# No value written here is a secret: the database, the gateway and the
# decryption keys are recreated on every run and destroyed with the runner.
# `scripts/check_secrets.sh` is what refuses them on a deployment.
#
# Usage: scripts/ci/prepare_environment.sh
#
# Recognised variables:
#   FORCER=1  overwrites existing files (see the guard below)
#   <any variable a template declares>  replaces the value it carries
#   RAILS_ENV, SECRET_KEY_BASE  added to .env.oots, which no template declares

set -e

# The templates are the list, here as everywhere else in this script and in
# scripts/check_environment.sh: .gitignore keeps `.env*` out of the repository
# and lets `.env*.template` back in, which makes them exactly the versioned
# ones. A template added later is therefore covered without being named here.
FICHIERS=""
for gabarit in .env*.template; do
  if [ ! -e "$gabarit" ]; then
    echo "❌ Aucun fichier .env*.template à la racine du dépôt : le clone est-il complet ?" >&2
    exit 1
  fi

  FICHIERS="$FICHIERS ${gabarit%.template}"
done

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

# The two variables no template declares, because they must not exist without a
# value: declared empty, `RAILS_ENV=` is not absent for Ruby, and the test
# suites — which set `test` only when it is missing — would run in
# `development`. `scripts/setup_server.sh` is what sets them.
#
# Judged here, before anything is written: refused after the loop below, the
# four files would already be on disk, and every replay would meet the guard
# above instead of the fault.
if [ -n "${RAILS_ENV:-}" ] && [ -z "${SECRET_KEY_BASE:-}" ]; then
  echo "❌ RAILS_ENV=$RAILS_ENV sans SECRET_KEY_BASE." >&2
  echo "   Rails refuserait de démarrer, et le dirait trois étapes plus loin." >&2
  exit 1
fi

# The value a template gives a variable, its end-of-line comment removed. The
# comment starts at the first space followed by `#`, which is also the only
# shape docker compose reads as a comment: `PORT_X=8180#note` is to it the value
# `8180#note`, which it refuses with `invalid hostPort`.
valeurDuGabarit() {
  valeur=$(sed -n "s/^$1=//p" "$2" | head -n 1)
  printf '%s' "${valeur%% #*}"
}

# What a variable is worth here: the environment if it defines it, be it to the
# empty string, and the template otherwise. `printenv` and not an expansion, so
# that a value carrying quotes, JSON braces or a `$` is never re-parsed.
valeurEffective() {
  if printenv "$1" >/dev/null 2>&1; then
    printenv "$1"
  else
    valeurDuGabarit "$1" "$2"
  fi
}

# The addresses this deployment answers at are composed out of the ports, so
# that shifting a port — what scripts/worktree.sh does — carries them along.
# `.env.template` spells the same values out for the default ports, which is
# what a reader needs to know what they look like.
PORT_OOTS_FRANCE=$(valeurEffective PORT_OOTS_FRANCE .env.template)
PORT_FAUX_FRANCE_CONNECT=$(valeurEffective PORT_FAUX_FRANCE_CONNECT .env.template)

# Where this deployment answers, for the browser as for the container: `web`
# listens on the port it publishes, so one `localhost:…` serves the two
# audiences — the browser following the redirection FranceConnect+ hands it, and
# the procedure calling its own contract.
URL_OOTS_FRANCE="${URL_OOTS_FRANCE-http://localhost:$PORT_OOTS_FRANCE}"

# The fake FranceConnect+, sole FranceConnect+ of the local stack: the browser
# follows the European flow there and `web` fetches the discovery document, the
# token and the JWKS there, under this one name. Its two credentials come from
# .env.oots.template, being constants of this repository; the three variables of
# the real one stay empty, the sandbox requiring a declared domain — so a fresh
# clone gets the one card, with nothing to edit by hand.
#
# `${VAR-…}` and not `${VAR:-…}`: emptying it is how a deployment says it offers
# no fake, and a default must not fill it back in.
URL_FAUX_FRANCE_CONNECT="${URL_FAUX_FRANCE_CONNECT-http://localhost:$PORT_FAUX_FRANCE_CONNECT/api/v2}"

# Where the demonstration procedure receives what is addressed to it, which is
# **not** a path under URL_OOTS_FRANCE: the evidence is delivered by the
# background worker, in a container of its own where `localhost` is the worker.
# A service name, as the fake requester of the end-to-end suite already uses —
# see docs/test_e2e.md.
URL_DEMARCHE="http://web:$PORT_OOTS_FRANCE/demo"

# Written out rather than defaulted with `${VAR-…}`: the value carries braces of
# its own, and the first `}` would close the expansion instead of the JSON
# object — which produces a truncated directory nothing complains about until a
# requester goes unrecognised.
if ! printenv DONNEES_REQUETEURS >/dev/null 2>&1; then
  DONNEES_REQUETEURS="{\"00000000000002\":{\"nom\":\"Requêteur de test\",\"url\":\"http://web:4000\"},\"00000000000003\":{\"nom\":\"Université de démonstration\",\"url\":\"$URL_DEMARCHE\"}}"
fi

export PORT_OOTS_FRANCE PORT_FAUX_FRANCE_CONNECT
export URL_OOTS_FRANCE URL_FAUX_FRANCE_CONNECT DONNEES_REQUETEURS

# The credentials of the two databases live in two files each, under the names
# their image expects and under the names the application reads. Held in step
# here rather than asked twice: the application presents the first, the image
# creates the role with the second, and nothing checks the equality before
# `db:prepare` meets `password authentication failed`.
MYSQL_PASSWORD=$(valeurEffective MYSQL_PASSWORD .env.domibus.template)
DB_USER=$(valeurEffective MYSQL_USER .env.domibus.template)
DB_PASS="$MYSQL_PASSWORD"
UTILISATEUR_BASE_DE_DONNEES=$(valeurEffective POSTGRES_USER .env.postgres.template)
MOT_DE_PASSE_BASE_DE_DONNEES=$(valeurEffective POSTGRES_PASSWORD .env.postgres.template)
NOM_BASE_DE_DONNEES=$(valeurEffective POSTGRES_DB .env.postgres.template)
export MYSQL_PASSWORD DB_USER DB_PASS
export UTILISATEUR_BASE_DE_DONNEES MOT_DE_PASSE_BASE_DE_DONNEES NOM_BASE_DE_DONNEES

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

# The private decryption keys are generated on the fly: nothing to version, and
# every run starts from fresh secrets. Ruby's standard library is enough, with
# no gem.
#
# RSA-OAEP-256, and not ECDH-ES: it is the only key management algorithm the Ruby
# gems actually handle — the one `apistration` already uses. FranceConnect+
# accepts both and nothing else, so the choice satisfies it too; on the token
# side nothing requires it, that token being the interface between a French
# procedure and this component, which no TDD chapter constrains. The routes that
# publish these keys do so by subtracting the secret components, so the key type
# stays free and the choice reversible.
engendreCleJwk() {
  executeRuby -ropenssl -rjson -rbase64 -e '
cle = OpenSSL::PKey::RSA.generate(2048)
b64 = ->(bn) { Base64.urlsafe_encode64(bn.to_s(2), padding: false) }

jwk = {
  kty: "RSA", alg: "RSA-OAEP-256", use: "enc",
  n: b64[cle.n], e: b64[cle.e], d: b64[cle.d],
  p: b64[cle.p], q: b64[cle.q],
  dp: b64[cle.dmp1], dq: b64[cle.dmq1], qi: b64[cle.iqmp],
}

puts Base64.strict_encode64(JSON.generate(jwk))
'
}

# La clé dont la démarche de démonstration **signe** le jeton du bénéficiaire,
# là où les deux ci-dessus déchiffrent. `BeneficiaryToken::SIGNATURE` n'admet
# qu'ES256, donc une courbe P-256 et non du RSA : c'est l'algorithme qui décide
# du type de clé, pas l'inverse.
#
# La RFC 7518 §6.2 veut chaque membre sur 32 octets fixes. `x` et `y` le sont
# par construction, découpés dans le point non compressé ; `d`, lui, vient d'un
# entier, et `to_s(2)` en rend la représentation minimale — une clé privée
# commençant par un octet nul produirait un membre trop court, que rien ne
# rejetterait avant la première signature, d'où le `rjust`.
engendreCleJwkEc() {
  executeRuby -ropenssl -rjson -rbase64 -e '
cle = OpenSSL::PKey::EC.generate("prime256v1")
point = cle.public_key.to_octet_string(:uncompressed)
b64 = ->(octets) { Base64.urlsafe_encode64(octets, padding: false) }

jwk = {
  kty: "EC", crv: "P-256", alg: "ES256", use: "sig",
  x: b64[point[1, 32]], y: b64[point[33, 32]],
  d: b64[cle.private_key.to_s(2).rjust(32, "\x00")],
}

puts Base64.strict_encode64(JSON.generate(jwk))
'
}

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
#
# The variable is named in the message, three keys being generated: « la clé
# JWK » alone would leave the reader to guess which of the three.
#
# The third argument is the last member the generator writes — `qi` for an RSA
# key, `d` for an EC one — because the two key types have no member in common
# that comes last for both. The caller names it rather than this function
# guessing from the payload: a check that reads the key it is checking would
# accept whatever that key happens to end with.
verifieCleJwk() {
  CLE_JWK_DECODEE=$(echo "$1" | base64 -d 2>/dev/null) || {
    echo "❌ La clé JWK produite pour $2 n'est pas du base64 valide." >&2
    exit 1
  }

  # That last member, and `}` closing the object: looking for `kty`, which comes
  # first, would let through a key truncated right after it — and so stripped of
  # all the cryptographic material.
  DERNIER_MEMBRE="\"$3\""
  case "$CLE_JWK_DECODEE" in
    *"$DERNIER_MEMBRE"*'}') ;;
    *)
      echo "❌ La clé JWK produite pour $2 est incomplète." >&2
      exit 1
      ;;
  esac
}

# Three keys, and not one shared: the first opens the beneficiary token a French
# service provider encrypts for this component, the second the ID Token
# FranceConnect+ encrypts for the demonstration procedure, the third signs the
# beneficiary token that same procedure emits. Three interfaces — lending one
# key to several would tie together what nothing ties.
#
# The third one signs where the two others decrypt, hence a curve rather than
# RSA: chapter 4.5.1 leaves the token unspecified, but `BeneficiaryToken`
# admits ES256 alone, which no RSA key can produce.
#
# No template writes them down: a key is worth being fresh, and there is no
# value to carry.
CLE_PRIVEE_JWK_EN_BASE64=$(engendreCleJwk)
verifieCleJwk "$CLE_PRIVEE_JWK_EN_BASE64" CLE_PRIVEE_JWK_EN_BASE64 qi

CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64=$(engendreCleJwk)
verifieCleJwk "$CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64" CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64 qi

CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64=$(engendreCleJwkEc)
verifieCleJwk "$CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64" CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64 d

export CLE_PRIVEE_JWK_EN_BASE64 CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64
export CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64

# A line stripped of its indentation, so that the continuation of an end-of-line
# comment reads like the comment it continues.
deblanchi() {
  printf '%s' "${1#"${1%%[![:space:]]*}"}"
}

# One file per template, each line of which is either prose, dropped, or a
# variable, kept with the value the environment or the template gives it: an
# end-of-line comment reaches docker compose as part of the value unless it is
# preceded by a space, and the blank lines are what keeps the groups apart. A
# blank line is held back until the next variable is written, so that neither
# the header's nor the trailing ones reach the file.
#
# A line that is neither stops the run rather than being skipped. That is the
# whole point of naming the two shapes: a key in lower case, a space around the
# `=`, and the variable would simply be missing from the file — which nothing
# downstream would catch, scripts/check_environment.sh reading the templates
# through the same character class and not considering such a line a
# declaration either.
ecrisDepuisLeGabarit() {
  fichier="${1%.template}"
  : > "$fichier"
  enAttente=""

  while IFS= read -r ligne || [ -n "$ligne" ]; do
    nu=$(deblanchi "$ligne")

    if [ -z "$nu" ]; then
      enAttente="oui"
      continue
    fi

    case "$nu" in
      '#'*) continue ;;
    esac

    cle="${ligne%%=*}"
    case "$ligne" in
      *=*) ;;
      *) cle="" ;;
    esac
    case "$cle" in
      '' | *[!A-Z_0-9]*)
        echo "❌ $1 : « $ligne » n'est ni de la prose ni une déclaration." >&2
        echo "   Une déclaration s'écrit NOM=valeur, sans espace autour du \`=\`," >&2
        echo "   en majuscules, chiffres et tirets bas ; une ligne de prose commence" >&2
        echo "   par un \`#\`. Toute autre forme serait écartée sans que rien ne le dise." >&2
        exit 1
        ;;
    esac

    valeur=$(valeurEffective "$cle" "$1")

    [ -z "$enAttente" ] || printf '\n' >> "$fichier"
    enAttente=""
    printf '%s=%s\n' "$cle" "$valeur" >> "$fichier"
  done < "$1"
}

for gabarit in .env*.template; do
  ecrisDepuisLeGabarit "$gabarit"
done

# The pair judged at the top, once the file it belongs in exists.
[ -z "${RAILS_ENV:-}" ] ||
  printf '\nRAILS_ENV=%s\nSECRET_KEY_BASE=%s\n' "$RAILS_ENV" "$SECRET_KEY_BASE" >> .env.oots

# What a template declares and the file derived from it carries agree by
# construction, the loop above refusing every line it cannot read. The check
# stays all the same: it is the one that reads the two files rather than the
# rule that writes them, and it costs a `grep` per variable.
CONSEIL="Corriger la ligne fautive du template, ou scripts/ci/prepare_environment.sh." scripts/check_environment.sh

echo "Fichiers$FICHIERS écrits."
