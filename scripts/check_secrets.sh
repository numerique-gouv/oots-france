#!/bin/sh
# Confronts the secrets an installation carries with the development values the
# templates publish, and refuses the ones that never changed. Those values are
# versioned in this repository: a deployment that kept them is open to whoever
# reads it, and nothing else says so — the stack answers exactly as it would
# with real ones.
#
# It reads and never writes, like scripts/check_environment.sh, and names every
# offender at once rather than the first. **It refuses whatever it could not
# check**, rather than staying silent: a control that passes wrongly is the one
# way this script can be worse than not existing.
#
# Usage: make check-secrets   (or scripts/check_secrets.sh)
#
# Where it does not belong: `make setup` and the `make check-env` it chains
# write and read a development machine's own values, which are the templates' —
# this check would fail there every time. A server replays it after any change
# to a .env*, and docs/deploiement.md says where.

set -e

cd "$(dirname "$0")/.."

# The two variables scripts/secret_variables deliberately leaves out, being
# recopies that scripts/ci/prepare_environment.sh keeps equal to the two
# passwords above them. Checked all the same: the file they live in is
# hand-editable, and a recopy left behind is as readable as its original.
RECOPIES="DB_PASS MOT_DE_PASSE_BASE_DE_DONNEES"

# The one name no template declares, and must not: declared empty, `RAILS_ENV=`
# would make the test suites run in `development` — see .env.oots.template. Its
# own check is at the end. Any other name a template fails to declare is a
# mistake, and refused as one.
SANS_GABARIT="SECRET_KEY_BASE"

ERREURS=""
signale() {
  ERREURS="${ERREURS:+$ERREURS
}$1"
}

# A value as docker compose reads it — the end-of-line comment starts at the
# first space followed by `#`, and everything before it is the value; the
# generated files carry none, but a file edited by hand may — and then trimmed,
# so that « empty » here means what it means to the application. `Settings`
# judges a value by `value.strip.empty?`, so a `NOM= ` left by a hand edit is
# absent to it and would be present to a `[ -z … ]` on the raw value: this
# script would bless a pair Rails then refuses to start on.
valeur() {
  lue=$(sed -n "s/^$1=//p" "$2" | head -n 1)
  lue="${lue%% #*}"
  lue="${lue#"${lue%%[![:space:]]*}"}"
  printf '%s' "${lue%"${lue##*[![:space:]]}"}"
}

declaree() {
  grep -q "^$1=" "$2"
}

# Whether a space-separated list holds a word — the lists below are built one
# name at a time and read three times.
contient() {
  case " $2 " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

# What is installed, and what is not. A machine where nothing is installed has
# nothing to answer for; one where a file is missing and others are there is a
# broken installation, and its missing file carries secrets nobody has looked
# at — which is exactly what this script must not pass over in silence.
INSTALLES=""
ABSENTS=""
for gabarit in .env*.template; do
  if [ ! -e "$gabarit" ]; then
    echo "❌ Aucun fichier .env*.template à la racine du dépôt : le clone est-il complet ?" >&2
    exit 1
  fi

  fichier="${gabarit%.template}"
  if [ ! -e "$fichier" ]; then
    ABSENTS="$ABSENTS $fichier"
  elif [ ! -r "$fichier" ] || [ ! -r "$gabarit" ]; then
    signale "❌ $fichier ou $gabarit illisible : ses secrets n'ont pas pu être vérifiés."
  else
    INSTALLES="$INSTALLES $fichier"
  fi
done

if [ -z "$INSTALLES" ] && [ -z "$ERREURS" ]; then
  echo "Aucun fichier d'environnement installé : rien à vérifier."
  exit 0
fi

[ -z "$ABSENTS" ] ||
  signale "❌ Installation incomplète, les secrets de ces fichiers n'ont été comparés à rien :$ABSENTS"

# The first column of scripts/secret_variables; the second says how to generate
# one, which only scripts/setup_server.sh needs. Read as scripts/setup_server.sh
# reads it, word by word: a pattern of its own would let a line through there
# and drop it here — a secret engendered on the server and compared to nothing,
# for ever, in silence. Which is the one outcome this script exists to prevent,
# so a line it cannot read stops it.
NOMS=""
while read -r nom reste; do
  case "$nom" in
    '' | '#'*) continue ;;
    *[!A-Z_0-9]*)
      echo "❌ scripts/secret_variables : « $nom $reste » ne nomme pas une variable." >&2
      echo "   Un nom s'écrit en majuscules, chiffres et tirets bas, sans rien devant." >&2
      exit 1
      ;;
  esac

  NOMS="$NOMS $nom"
done < scripts/secret_variables

if [ -z "$NOMS" ]; then
  echo "❌ scripts/secret_variables ne nomme aucune variable : son format a-t-il changé ?" >&2
  exit 1
fi

# The template that declares a variable is both where its development value is
# written and which file to look for it in — `.env.oots.template` names
# `.env.oots`.
gabaritDe() {
  for gabarit in .env*.template; do
    ! declaree "$1" "$gabarit" || { printf '%s' "$gabarit"; return 0; }
  done
}

for nom in $NOMS $RECOPIES; do
  gabarit=$(gabaritDe "$nom")

  if [ -z "$gabarit" ]; then
    contient "$nom" "$SANS_GABARIT" && continue

    signale "❌ $nom : aucun template ne le déclare, il n'a donc été comparé à rien."
    continue
  fi

  fichier="${gabarit%.template}"
  # Already reported above, as a missing file or an unreadable one.
  contient "$fichier" "$INSTALLES" || continue

  installee=$(valeur "$nom" "$fichier")

  if [ "$installee" = "$(valeur "$nom" "$gabarit")" ]; then
    signale "❌ $fichier : $nom porte encore la valeur de développement de $gabarit."
    continue
  fi

  # Empty is worse than a development value, and no comparison catches it: a
  # secret whose lookup failed in an automation reaches the file as `NOM=`, and
  # an empty string is never equal to the template's. The exception is the
  # restricted database role, which `Settings.application_database_role` reads
  # as both or neither — left empty, `web` and `worker` connect as the owner.
  # Emptied on one side only, it is neither, and the check below says so.
  if [ -z "$installee" ]; then
    if [ "$nom" = "MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES" ] &&
       [ -z "$(valeur UTILISATEUR_APPLICATIF_BASE_DE_DONNEES "$fichier")" ]; then
      continue
    fi

    signale "❌ $fichier : $nom est vide."
  fi
done

# The credentials of the fake FranceConnect+ are constants of the repository,
# and legitimately kept: they are the fake's, and a deployment declares the fake
# and the real one side by side. What must never be kept is one of them in front
# of the real FranceConnect+, which delivers a secret of its own.
if contient .env.oots "$INSTALLES"; then
  # The other half of « both or neither ». A username emptied by hand, next to
  # the password a run engendered, is the pair broken the way no comparison
  # above sees: the password is neither the template's nor empty. `Settings`
  # refuses it at boot — the `docker compose up -d web worker` that ends
  # « Mettre à jour » — where this script is what docs/deploiement.md sends an
  # operator to as that sequence begins.
  if [ -z "$(valeur UTILISATEUR_APPLICATIF_BASE_DE_DONNEES .env.oots)" ] &&
     [ -n "$(valeur MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES .env.oots)" ]; then
    signale "❌ .env.oots : MOT_DE_PASSE_APPLICATIF_BASE_DE_DONNEES est posé sans UTILISATEUR_APPLICATIF_BASE_DE_DONNEES."
  fi

  # The real FranceConnect+ declared with the secret the template publishes for
  # the fake: that value is versioned in this repository, and whoever reads it
  # can present themselves to the real portal as this deployment. The issuer is
  # what says the real one is declared at all — an empty one declares nothing,
  # and its credentials are then read by nobody.
  if [ -n "$(valeur URL_VRAI_FRANCE_CONNECT .env.oots)" ] &&
     [ "$(valeur SECRET_CLIENT_VRAI_FRANCE_CONNECT .env.oots)" = "$(valeur SECRET_CLIENT_FAUX_FRANCE_CONNECT .env.oots.template)" ]; then
    signale "❌ .env.oots : SECRET_CLIENT_VRAI_FRANCE_CONNECT porte le secret que .env.oots.template publie pour le faux FranceConnect+."
  fi

  # No template declares either, for the reason SANS_GABARIT gives. So this is
  # the only place the pair is checked, and Rails would otherwise refuse to
  # start on `Missing secret_key_base`.
  if [ "$(valeur RAILS_ENV .env.oots)" = "production" ] && [ -z "$(valeur SECRET_KEY_BASE .env.oots)" ]; then
    signale "❌ .env.oots : RAILS_ENV=production sans SECRET_KEY_BASE."
  fi
fi

if [ -n "$ERREURS" ]; then
  echo "$ERREURS" >&2
  echo "   Une valeur de développement est publiée dans ce dépôt ; une valeur vide ne" >&2
  echo "   protège rien. Les remplacer, puis refaire les volumes et les magasins qui en" >&2
  echo "   dépendent — voir docs/deploiement.md." >&2
  exit 1
fi

echo "✓ Aucun secret de développement, ni vide, dans :$INSTALLES"
