#!/bin/sh
# Écrit les fichiers .env* attendus par docker compose, avec des valeurs jetables
# destinées à l'intégration continue (cf. docs/test_e2e.md).
#
# Aucune valeur n'est un secret : la base, la passerelle et la clé de
# déchiffrement sont recréées à chaque exécution et détruites avec le runner.
#
# Usage : scripts/ci/preparEnvironnement.sh
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
# scripts/configureDomibus.sh : c'est le compte que le script crée dans Domibus
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
# que scripts/configureDomibus.sh renseigne.
LOGIN_NOTIFICATION_DOMIBUS="${LOGIN_NOTIFICATION_DOMIBUS:-domibus_push}"
MOT_DE_PASSE_NOTIFICATION_DOMIBUS="${MOT_DE_PASSE_NOTIFICATION_DOMIBUS:-Push-OotsFrance-2026!}"

# Heredoc non quoté : les valeurs ci-dessus doivent être substituées.
cat > .env <<FIN
PORT_DOMIBUS=8180
PORT_OOTS_FRANCE=3000
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
CLE_PRIVEE_JWK_EN_BASE64=$(ruby -ropenssl -rjson -rbase64 -e '
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

# L'annuaire déclare deux démarches sur le même type de justificatif : `00` pour
# le scénario nominal du test de bout en bout, `T3` pour son scénario d'erreur.
# Les deux doivent y figurer, cf. docs/test_e2e.md.
cat > .env.oots <<FIN
AVEC_REQUETE_PIECE_JUSTIFICATIVE=true
CLE_PRIVEE_JWK_EN_BASE64=$CLE_PRIVEE_JWK_EN_BASE64
DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL={"typesJustificatif":[{"id":"https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000","descriptions":{"FR":"Justificatif de test","EN":"Test evidence"},"formatDistribution":"application/pdf","fournisseurs":{"FR":[{"pointAcces":{"id":"blue_gw","typeId":"urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots"},"descriptions":{"FR":"Fournisseur de test"}}]}}],"demarches":[{"code":"00","idsTypeJustificatif":["https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000"]},{"code":"T3","idsTypeJustificatif":["https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000"]}]}
DONNEES_REQUETEURS={"00000000000002":{"nom":"Requêteur de test","url":"http://web:4000"}}
IDENTIFIANT_FOURNISSEUR_FRANCAIS=00000000000001
NOM_FOURNISSEUR_FRANCAIS=Fournisseur de test
URL_OOTS_FRANCE=http://localhost:3000

DELAI_MAX_ATTENTE_DOMIBUS=30000
IDENTIFIANT_EXPEDITEUR_DOMIBUS=blue_gw
SUFFIXE_IDENTIFIANTS_DOMIBUS=oots.eu
TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS=urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots
URL_BASE_DOMIBUS=http://domibus:8080/domibus

LOGIN_API_REST=$LOGIN_API_REST
MOT_DE_PASSE_API_REST=$MOT_DE_PASSE_API_REST
LOGIN_NOTIFICATION_DOMIBUS=$LOGIN_NOTIFICATION_DOMIBUS
MOT_DE_PASSE_NOTIFICATION_DOMIBUS=$MOT_DE_PASSE_NOTIFICATION_DOMIBUS

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

# Le template déclare le contrat : toute variable qu'il nomme doit être écrite
# ici. Sans ce contrôle, l'oubli d'une variable nouvellement obligatoire ne se
# voit qu'au démarrage de l'application, deux étapes plus loin, sous la forme
# d'une attente qui expire sans rien dire.
MANQUANTES=""
for variable in $(sed -n 's/^\([A-Z_][A-Z_0-9]*\)=.*/\1/p' .env.oots.template); do
  grep -q "^$variable=" .env.oots || MANQUANTES="$MANQUANTES $variable"
done

if [ -n "$MANQUANTES" ]; then
  echo "❌ Variables déclarées par .env.oots.template et absentes de .env.oots :$MANQUANTES" >&2
  echo "   Compléter scripts/ci/preparEnvironnement.sh." >&2
  exit 1
fi

echo "Fichiers .env, .env.domibus, .env.oots et .env.postgres écrits."
