#!/bin/sh
# Configure une instance Domibus fraîche, sans passer par la console web.
#
# Reproduit les étapes décrites dans le README (charger le PMode, créer le
# Plugin User) via l'API REST d'administration, pour que l'intégration continue
# puisse monter une passerelle utilisable sans intervention humaine.
#
# Usage : scripts/configureDomibus.sh
#
# Variables reconnues (valeurs par défaut entre parenthèses) :
#   URL_DOMIBUS                 URL de la console ; à défaut, PORT_DOMIBUS
#                               compose http://localhost:${PORT_DOMIBUS:-8180}/domibus
#   DOMIBUS_ADMIN               compte console admin (admin)
#   DOMIBUS_MOT_DE_PASSE_ADMIN  mot de passe console (123456)
#   LOGIN_API_REST              Plugin User à créer — obligatoire
#   MOT_DE_PASSE_API_REST       son mot de passe — obligatoire, 16 à 32
#                               caractères, avec majuscule, minuscule, chiffre
#                               et caractère spécial, sans quoi Domibus le
#                               refuse
#
# Ces deux identifiants doivent être ceux du fichier .env.oots avec lequel
# tourne l'application : c'est le compte qu'elle présentera à la passerelle. Ils
# sont exigés plutôt que déduits, un .env.oots n'étant pas chargeable depuis un
# script shell — ses valeurs contiennent `&` et des accolades JSON.
#   FICHIER_PMODE               PMode à charger (exemples/configuration_PMode_Domibus.xml)
#   FICHIER_TRUSTSTORE          truststore à imposer, ignoré s'il est absent
#                               (domibus/keystores/gateway_truststore.jks)
#   MOT_DE_PASSE_TRUSTSTORE     son mot de passe (test123, cf. genereCertificats.sh)

set -e

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DOMIBUS_ADMIN="${DOMIBUS_ADMIN:-admin}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-123456}"
LOGIN_API_REST="${LOGIN_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
MOT_DE_PASSE_API_REST="${MOT_DE_PASSE_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
FICHIER_PMODE="${FICHIER_PMODE:-exemples/configuration_PMode_Domibus.xml}"
FICHIER_TRUSTSTORE="${FICHIER_TRUSTSTORE:-domibus/keystores/gateway_truststore.jks}"
# Indiqué pour la lisibilité du journal : c'est Domibus qui le relit, à
# l'emplacement que lui donne domibus.security.keystore.location.
FICHIER_KEYSTORE="domibus/keystores/gateway_keystore.jks"
MOT_DE_PASSE_TRUSTSTORE="${MOT_DE_PASSE_TRUSTSTORE:-test123}"

BOCAL=$(mktemp)
REPONSE=$(mktemp)
trap 'rm -f "$BOCAL" "$REPONSE"' EXIT

# Les réponses de l'API sont préfixées par `)]}',` (protection Angular contre le
# détournement de JSON) : ce préfixe doit sauter avant tout parsage.
sansPrefixeJSON() { tail -c +7; }

echo "→ Authentification sur $URL_DOMIBUS en tant que $DOMIBUS_ADMIN"
if ! curl -sS -f -c "$BOCAL" -o /dev/null \
  -X POST "$URL_DOMIBUS/rest/security/authentication" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$DOMIBUS_ADMIN\",\"password\":\"$DOMIBUS_MOT_DE_PASSE_ADMIN\"}"; then
  echo "❌ Authentification refusée sur $URL_DOMIBUS (passerelle joignable ? identifiants ?)." >&2
  exit 1
fi

# Le jeton anti-CSRF est déposé en cookie et doit être renvoyé en en-tête sur
# toute requête modifiante.
JETON=$(awk '/XSRF-TOKEN/ { print $7 }' "$BOCAL")
if [ -z "$JETON" ]; then
  echo "❌ Aucun jeton XSRF reçu : authentification refusée ?" >&2
  exit 1
fi

appelAuthentifie() {
  curl -sS -b "$BOCAL" -H "X-XSRF-TOKEN: $JETON" "$@"
}

# Effectue un appel authentifié, range le corps de la réponse dans $REPONSE et
# renvoie le code HTTP. Domibus explique ses refus dans ce corps, que les
# messages d'échec restituent.
#
# Le `|| true` est indispensable : sur erreur réseau curl sort en échec, et
# `set -e` interromprait le script au milieu d'une substitution — avant le
# message qui explique ce qui s'est passé. curl écrit alors `000`, que les
# comparaisons de code traitent comme n'importe quel refus.
appelAvecCode() {
  appelAuthentifie -o "$REPONSE" -w '%{http_code}' "$@" || true
}

# Le préfixe `)]}',` ne coiffe que les réponses JSON de la console : une page
# d'erreur du serveur d'applications n'en a pas, et serait tronquée de six
# octets si on le retirait sans regarder.

messageDomibus() {
  if head -c 6 "$REPONSE" 2> /dev/null | grep -qF ")]}',"; then
    tail -c +7 "$REPONSE" | head -c 500
  else
    head -c 500 "$REPONSE" 2> /dev/null
  fi
}

# Les certificats livrés avec l'image étant expirés, on impose ceux du dépôt.
# Le remplacement est idempotent : recharger le même magasin est sans effet.
#
# Un truststore demandé mais introuvable arrête le script — le passer sous
# silence laisserait des certificats périmés en place, et la passerelle
# refuserait d'émettre sans autre symptôme qu'un délai dépassé côté application.
# Passer FICHIER_TRUSTSTORE vide pour conserver délibérément celui en place.
if [ -n "$FICHIER_TRUSTSTORE" ] && [ ! -f "$FICHIER_TRUSTSTORE" ]; then
  echo "❌ Truststore introuvable : $FICHIER_TRUSTSTORE" >&2
  exit 1
fi

if [ -n "$FICHIER_TRUSTSTORE" ]; then
  echo "→ Chargement du truststore $FICHIER_TRUSTSTORE"
  CODE_TRUSTSTORE=$(appelAvecCode \
    -F "file=@$FICHIER_TRUSTSTORE" \
    -F "password=$MOT_DE_PASSE_TRUSTSTORE" \
    "$URL_DOMIBUS/rest/truststore/save")
  if [ "$CODE_TRUSTSTORE" != "200" ]; then
    echo "❌ Chargement du truststore refusé ($CODE_TRUSTSTORE) : $(messageDomibus)" >&2
    exit 1
  fi
else
  echo "→ Pas de truststore demandé, on garde celui en place"
fi

# Le keystore, lui, ne se téléverse pas : Domibus 5.0.4 n'expose que sa
# relecture depuis le fichier — c'est le bouton « Reload KeyStore » de la
# console. Elle est indispensable : sans elle la passerelle signe avec la clé
# conservée en base depuis son premier démarrage, et refuse d'émettre
# (EBMS_0004, « sender certificate is not valid ») même le truststore corrigé.
echo "→ Relecture du keystore depuis $FICHIER_KEYSTORE"
CODE_KEYSTORE=$(appelAvecCode -X POST "$URL_DOMIBUS/rest/keystore/resets")
if [ "$CODE_KEYSTORE" != "200" ]; then
  echo "❌ Relecture du keystore refusée ($CODE_KEYSTORE) : $(messageDomibus)" >&2
  exit 1
fi

echo "→ Chargement du PMode $FICHIER_PMODE"
# Domibus répond 200 en signalant les avertissements du PMode : ceux du PMode
# d'exemple (rôles initiateur et répondeur identiques) sont attendus, puisque la
# passerelle dialogue avec elle-même.
CODE_PMODE=$(appelAvecCode \
  -F "file=@$FICHIER_PMODE" \
  -F "description=Configuration automatique" \
  "$URL_DOMIBUS/rest/pmode")
if [ "$CODE_PMODE" != "200" ]; then
  echo "❌ Chargement du PMode refusé ($CODE_PMODE) : $(messageDomibus)" >&2
  exit 1
fi

# Recréer un Plugin User existant échoue : on ne crée que s'il manque, pour que
# le script puisse être rejoué sans erreur.
echo "→ Vérification du Plugin User $LOGIN_API_REST"
EXISTE=$(appelAuthentifie "$URL_DOMIBUS/rest/plugin/users?pageSize=100&page=0&authType=BASIC" \
  | sansPrefixeJSON \
  | node -e "
    let e = '';
    process.stdin.on('data', (d) => { e += d; });
    process.stdin.on('end', () => {
      const utilisateurs = JSON.parse(e).entries ?? [];
      console.log(utilisateurs.some((u) => u.userName === process.argv[1]) ? 'oui' : 'non');
    });
  " "$LOGIN_API_REST")

if [ "$EXISTE" = "oui" ]; then
  echo "  déjà présent, rien à faire"
else
  echo "  création"
  CODE_UTILISATEUR=$(appelAvecCode \
    -X PUT "$URL_DOMIBUS/rest/plugin/users" \
    -H 'Content-Type: application/json' \
    -d "[{\"userName\":\"$LOGIN_API_REST\",\"password\":\"$MOT_DE_PASSE_API_REST\",\"authRoles\":\"ROLE_ADMIN\",\"authenticationType\":\"BASIC\",\"status\":\"NEW\",\"active\":true,\"suspended\":false,\"domain\":\"default\",\"originalUser\":null,\"certificateId\":null}]")
  if [ "$CODE_UTILISATEUR" != "204" ]; then
    echo "❌ Création du Plugin User refusée ($CODE_UTILISATEUR) : $(messageDomibus)" >&2
    echo "   Mot de passe non conforme ? 16 à 32 caractères, majuscule, minuscule, chiffre et spécial." >&2
    exit 1
  fi
fi

# Ultime garde-fou : c'est par ce compte, et sur cette route, que l'application
# résout les points d'accès. S'il échoue ici, il échouera dans le test.
echo "→ Vérification de l'accès à l'annuaire des parties"
CODE_PARTIE=$(curl -sS -o /dev/null -w '%{http_code}' \
  -u "$LOGIN_API_REST:$MOT_DE_PASSE_API_REST" \
  "$URL_DOMIBUS/ext/party?name=blue_gw" || true)
if [ "$CODE_PARTIE" != "200" ]; then
  echo "❌ L'annuaire des parties répond $CODE_PARTIE au Plugin User $LOGIN_API_REST." >&2
  exit 1
fi

echo "✅ Domibus configuré : PMode chargé, Plugin User $LOGIN_API_REST opérationnel"
