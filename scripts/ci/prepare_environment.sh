#!/bin/sh
# Écrit les fichiers .env* attendus par docker compose, avec des valeurs jetables
# destinées à l'intégration continue (cf. docs/test_e2e.md) et à l'installation
# locale, que scripts/setup.sh monte par-dessus.
#
# Aucune valeur n'est un secret : la base, la passerelle et la clé de
# déchiffrement sont recréées à chaque exécution et détruites avec le runner.
#
# Usage : scripts/ci/prepare_environment.sh
#
# Variables reconnues :
#   FORCER=1  écrase les fichiers existants (voir la garde ci-dessous)

set -e

FICHIERS=".env .env.domibus .env.oots .env.postgres"

# Ces fichiers ne sont pas versionnés : les écraser détruit une configuration
# locale irrécupérable. Sur un runner ils n'existent pas, et le script écrit
# sans rien demander ; ailleurs il s'arrête, à moins d'un FORCER=1 explicite.
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

# Ces identifiants doivent être les mêmes que ceux passés à
# scripts/configure_domibus.sh : c'est le compte que le script crée dans Domibus
# et celui avec lequel l'application s'y authentifie.
#
# Domibus impose au mot de passe 16 à 32 caractères, avec majuscule, minuscule,
# chiffre et caractère spécial : plus court, il est rejeté à la création.
LOGIN_API_REST="${LOGIN_API_REST:-oots_ci}"
MOT_DE_PASSE_API_REST="${MOT_DE_PASSE_API_REST:-Ci-OotsFrance-2026!}"

# Ce mot de passe protège les magasins de certificats. La passerelle le lit
# depuis .env, les scripts depuis l'environnement : le prendre d'ici garantit
# que les deux voient la même valeur, comme pour les identifiants ci-dessus.
MOT_DE_PASSE_MAGASINS="${MOT_DE_PASSE_MAGASINS:-test123}"

# Les identifiants que Domibus posera sur ses notifications vers nous. Ils
# doivent être les mêmes ici et dans `wsplugin.push.auth.*` côté passerelle,
# que scripts/configure_domibus.sh renseigne.
LOGIN_NOTIFICATION_DOMIBUS="${LOGIN_NOTIFICATION_DOMIBUS:-domibus_push}"
MOT_DE_PASSE_NOTIFICATION_DOMIBUS="${MOT_DE_PASSE_NOTIFICATION_DOMIBUS:-Push-OotsFrance-2026!}"

# Heredoc non quoté : les valeurs ci-dessus doivent être substituées.
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

# Le runner d'intégration continue installe Ruby pour lui-même ; un poste de
# développement n'a que Git et Docker pour prérequis, d'où le repli sur l'image
# officielle. La version se lit dans .ruby-version plutôt que d'être écrite ici :
# le dépôt épingle déjà la même valeur en plusieurs endroits, et n'en veut pas un
# de plus.
executeRuby() {
  if command -v ruby >/dev/null 2>&1; then
    ruby "$@"
    return
  fi

  # Sans cette garde, l'absence du fichier donnerait le tag `ruby:-slim` et une
  # erreur de référence Docker, sans rapport visible avec sa cause.
  if [ ! -f .ruby-version ]; then
    echo "❌ .ruby-version introuvable : lancer ce script depuis la racine du dépôt." >&2
    exit 1
  fi

  docker run --rm "ruby:$(cat .ruby-version)-slim" ruby "$@"
}

# La clé privée de déchiffrement est générée à la volée : rien à versionner, et
# chaque exécution repart d'un secret neuf. La bibliothèque standard de Ruby
# suffit, sans gem.
#
# RSA-OAEP-256, et non plus ECDH-ES : c'est le seul algorithme de gestion de clé
# que les gems Ruby traitent réellement — celle qu'emploie déjà `apistration`.
# Rien ne l'impose côté OOTS : ce jeton est l'interface entre une démarche
# française et cette brique, qu'aucun chapitre des TDD ne contraint. La route
# qui publie la clé le fait par soustraction des composantes secrètes, donc le
# type de clé reste libre et le choix réversible.
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

# Une sortie tronquée ou polluée serait recopiée telle quelle dans .env.oots.
# `Settings.verify!` ne l'y rattraperait pas : il n'écarte que les valeurs vides,
# et celle-ci n'en est pas une. L'échec n'apparaîtrait donc qu'au premier
# déchiffrement d'un jeton, loin d'ici. Le contrôle reste en `base64` seul : la
# machine qui a eu besoin du repli Docker ci-dessus n'a toujours pas de Ruby pour
# relire ce qu'il a produit.
#
# Le décodage est sorti du tube pour que son code de sortie soit celui qu'on
# teste : dans un tube, seul le dernier compte, et `base64 -d` écrit sur stdout
# tout ce qu'il a su décoder avant d'échouer.
CLE_JWK_DECODEE=$(echo "$CLE_PRIVEE_JWK_EN_BASE64" | base64 -d 2>/dev/null) || {
  echo "❌ La clé JWK produite n'est pas du base64 valide." >&2
  exit 1
}

# `qi` est le dernier champ que le générateur écrit, et `}` ferme l'objet :
# chercher `kty`, qui vient en tête, laisserait passer une clé tronquée juste
# après — donc amputée de tout le matériel cryptographique.
case "$CLE_JWK_DECODEE" in
  *'"qi"'*'}') ;;
  *)
    echo "❌ La clé JWK produite est incomplète." >&2
    exit 1
    ;;
esac

# Le fournisseur français garde son identité réelle plutôt qu'un nom de test :
# elle est recopiée dans le `ErrorProvider` des messages de référence de
# spec/fixtures/, et `spec/support/test_environment.rb` ne la pose qu'en `||=`.
# Un nom de test ici passerait dans le conteneur par `env_file` et ferait rougir
# la suite unitaire, que rien n'aurait pourtant modifiée.
#
# Les deux URL d'annuaire désignent le faux annuaire que la suite de bout en
# bout monte elle-même, et le magasin de confiance le certificat qu'il engendre
# au démarrage : c'est ce qui rend `make e2e` reproductible, là où les annuaires
# centraux réclameraient une inscription de la France que personne ici ne
# contrôle. Les vider et remettre config/certificats/services_communs_acc.pem
# rebranche la pile sur l'acceptation — voir docs/test_e2e.md.
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
IDENTIFIANT_EXPEDITEUR_DOMIBUS=blue_gw
SUFFIXE_IDENTIFIANTS_DOMIBUS=oots.eu
TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS=urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots
URL_BASE_DOMIBUS=http://domibus:8080/domibus

LOGIN_API_REST=$LOGIN_API_REST
MOT_DE_PASSE_API_REST=$MOT_DE_PASSE_API_REST
LOGIN_NOTIFICATION_DOMIBUS=$LOGIN_NOTIFICATION_DOMIBUS
MOT_DE_PASSE_NOTIFICATION_DOMIBUS=$MOT_DE_PASSE_NOTIFICATION_DOMIBUS

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

# Les mêmes valeurs, sous les noms qu'attend l'image PostgreSQL. Elles doivent
# rester en phase avec celles ci-dessus, comme .env.domibus l'impose déjà entre
# MYSQL_USER et DB_USER.
cat > .env.postgres <<'FIN'
POSTGRES_USER=oots_france
POSTGRES_PASSWORD=oots_france
POSTGRES_DB=oots_france
FIN

# Les templates déclarent le contrat : toute variable que l'un d'eux nomme doit
# être écrite ici. Sans ce contrôle, l'oubli d'une variable nouvellement
# obligatoire ne se voit qu'au démarrage de la pile, deux étapes plus loin, sous
# la forme d'une attente qui expire sans rien dire.
ERREURS=""
signale() {
  ERREURS="${ERREURS:+$ERREURS
}$1"
}

for fichier in $FICHIERS; do
  # Un template absent ferait échouer le `sed` ci-dessous dans une substitution
  # de commande, dont le shell ne regarde pas le statut : la boucle tournerait à
  # vide et le contrôle passerait, rétablissant l'attente muette qu'il existe
  # justement pour empêcher.
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

# Les quatre fichiers sont rapportés d'un coup : sortir au premier fautif
# masquerait les suivants, et coûterait autant d'allers-retours que de fichiers.
if [ -n "$ERREURS" ]; then
  echo "$ERREURS" >&2
  echo "   Compléter scripts/ci/prepare_environment.sh." >&2
  exit 1
fi

echo "Fichiers .env, .env.domibus, .env.oots et .env.postgres écrits."
