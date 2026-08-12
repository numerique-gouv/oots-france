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
#   REPERTOIRE_MAGASINS         où lire keystore et truststore ; à défaut, ils
#                               sont générés dans un répertoire temporaire par
#                               scripts/genereCertificats.sh
#   MOT_DE_PASSE_MAGASINS       leur mot de passe — obligatoire, et devant
#                               correspondre à celui du .env avec lequel tourne
#                               la passerelle

set -e

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DOMIBUS_ADMIN="${DOMIBUS_ADMIN:-admin}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-123456}"
LOGIN_API_REST="${LOGIN_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
MOT_DE_PASSE_API_REST="${MOT_DE_PASSE_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
FICHIER_PMODE="${FICHIER_PMODE:-exemples/configuration_PMode_Domibus.xml}"
MOT_DE_PASSE_MAGASINS="${MOT_DE_PASSE_MAGASINS:?doit être renseigné, et correspondre à celui de .env}"
PARTIE="blue_gw"

# Le répertoire monté dans la passerelle, où vivent les propriétés du plugin.
REPERTOIRE_DOMIBUS="${REPERTOIRE_DOMIBUS:-domibus}"

# L'adresse à laquelle la passerelle nous notifie, et les identifiants qu'elle
# posera dessus. Vus depuis le conteneur Domibus, d'où le nom de service.
URL_NOTIFICATION="${URL_NOTIFICATION:-http://web:3000/domibus/notifications}"
LOGIN_NOTIFICATION_DOMIBUS="${LOGIN_NOTIFICATION_DOMIBUS:-domibus_push}"
MOT_DE_PASSE_NOTIFICATION_DOMIBUS="${MOT_DE_PASSE_NOTIFICATION_DOMIBUS:-Push-OotsFrance-2026!}"

BOCAL=$(mktemp)
REPONSE=$(mktemp)
trap 'rm -f "$BOCAL" "$REPONSE"' EXIT

# Les réponses de l'API sont préfixées par `)]}',` (protection Angular contre le
# détournement de JSON) : ce préfixe doit sauter avant tout parsage.
sansPrefixeJSON() { tail -c +7; }

echo "→ Authentification sur $URL_DOMIBUS en tant que $DOMIBUS_ADMIN"
if ! curl -sS -f -c "$BOCAL" -o /dev/null \
  -X POST "$URL_DOMIBUS/rest/public/security/authentication" \
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

# Les certificats livrés avec l'image sont publics et partagés par toutes les
# installations : on impose les nôtres. À défaut de magasins fournis, on les
# génère — ils n'ont pas à survivre au script, la passerelle les conservant en
# base une fois téléversés.
if [ -z "$REPERTOIRE_MAGASINS" ]; then
  REPERTOIRE_MAGASINS=$(mktemp -d)
  trap 'rm -f "$BOCAL" "$REPONSE"; rm -rf "$REPERTOIRE_MAGASINS"' EXIT
  echo "→ Génération des magasins dans $REPERTOIRE_MAGASINS"
  DESTINATION="$REPERTOIRE_MAGASINS" MOT_DE_PASSE_MAGASINS="$MOT_DE_PASSE_MAGASINS" \
    "$(dirname "$0")/genereCertificats.sh" > /dev/null
fi

# Les deux magasins se posent par la même API depuis Domibus 5.1 : le détour du
# keystore par le disque, que 5.0.4 imposait, n'a plus lieu d'être.
#
# allowChangingDiskStoreProps laisse Domibus aligner ses propriétés de magasin
# sur le fichier reçu. Il ne le fait que pour le truststore — le type et
# l'emplacement du keystore sont imposés au démarrage, voir docker-compose.yml.
chargeMagasin() {
  magasinNom="$1"
  magasinFichier="$REPERTOIRE_MAGASINS/gateway_$1.p12"

  if [ ! -f "$magasinFichier" ]; then
    echo "❌ Magasin introuvable : $magasinFichier" >&2
    exit 1
  fi

  echo "→ Chargement du $magasinNom $magasinFichier"
  # --form-string plutôt que -F pour les valeurs : -F traite un « @ » ou un
  # « < » en tête comme un nom de fichier à lire, ce qui enverrait son contenu
  # à la place du mot de passe. Seul le magasin lui-même est un vrai fichier.
  magasinCode=$(appelAvecCode \
    -F "file=@$magasinFichier" \
    --form-string "password=$MOT_DE_PASSE_MAGASINS" \
    --form-string "allowChangingDiskStoreProps=true" \
    "$URL_DOMIBUS/rest/internal/admin/$magasinNom/save")
  if [ "$magasinCode" != "200" ]; then
    echo "❌ Chargement du $magasinNom refusé ($magasinCode) : $(messageDomibus)" >&2
    exit 1
  fi
}

chargeMagasin truststore
chargeMagasin keystore

echo "→ Chargement du PMode $FICHIER_PMODE"
# Domibus répond 200 en signalant les avertissements du PMode : ceux du PMode
# d'exemple (rôles initiateur et répondeur identiques) sont attendus, puisque la
# passerelle dialogue avec elle-même.
CODE_PMODE=$(appelAvecCode \
  -F "file=@$FICHIER_PMODE" \
  --form-string "description=Configuration automatique" \
  "$URL_DOMIBUS/rest/internal/admin/pmode")
if [ "$CODE_PMODE" != "200" ]; then
  echo "❌ Chargement du PMode refusé ($CODE_PMODE) : $(messageDomibus)" >&2
  exit 1
fi

# Recréer un Plugin User existant échoue : on ne crée que s'il manque, pour que
# le script puisse être rejoué sans erreur.
echo "→ Vérification du Plugin User $LOGIN_API_REST"
EXISTE=$(appelAuthentifie "$URL_DOMIBUS/rest/internal/admin/plugin/users?pageSize=100&page=0&authType=BASIC" \
  | sansPrefixeJSON \
  | python3 -c "
import json, sys
utilisateurs = json.load(sys.stdin).get('entries') or []
print('oui' if any(u.get('userName') == sys.argv[1] for u in utilisateurs) else 'non')
" "$LOGIN_API_REST")

if [ "$EXISTE" = "oui" ]; then
  echo "  déjà présent, rien à faire"
else
  echo "  création"
  CODE_UTILISATEUR=$(appelAvecCode \
    -X PUT "$URL_DOMIBUS/rest/internal/admin/plugin/users" \
    -H 'Content-Type: application/json' \
    -d "[{\"userName\":\"$LOGIN_API_REST\",\"password\":\"$MOT_DE_PASSE_API_REST\",\"authRoles\":\"ROLE_ADMIN\",\"authenticationType\":\"BASIC\",\"status\":\"NEW\",\"active\":true,\"suspended\":false,\"domain\":\"default\",\"originalUser\":null,\"certificateId\":null}]")
  if [ "$CODE_UTILISATEUR" != "204" ]; then
    echo "❌ Création du Plugin User refusée ($CODE_UTILISATEUR) : $(messageDomibus)" >&2
    echo "   Mot de passe non conforme ? 16 à 32 caractères, majuscule, minuscule, chiffre et spécial." >&2
    exit 1
  fi
fi

# Premier garde-fou : c'est par ce compte, et sur cette route, que l'application
# résout les points d'accès. S'il échoue ici, il échouera dans le test.
echo "→ Vérification de l'accès à l'annuaire des parties"
CODE_PARTIE=$(curl -sS -o /dev/null -w '%{http_code}' \
  -u "$LOGIN_API_REST:$MOT_DE_PASSE_API_REST" \
  "$URL_DOMIBUS/ext/party?name=$PARTIE" || true)
if [ "$CODE_PARTIE" != "200" ]; then
  echo "❌ L'annuaire des parties répond $CODE_PARTIE au Plugin User $LOGIN_API_REST." >&2
  exit 1
fi

# Second garde-fou, autrement plus parlant : le test de connectivité de la
# console — l'« avion en papier ». Il fait circuler un vrai message AS4 en
# boucle sur la passerelle, donc il exerce la signature et le chiffrement, et
# valide du même coup les alias des profils de sécurité. Le tout sans rien
# devoir à l'application : s'il passe et que le test de bout en bout échoue,
# la passerelle est hors de cause.
echo "→ Test de connectivité $PARTIE → $PARTIE"
CODE_TEST=$(appelAvecCode \
  -X POST "$URL_DOMIBUS/rest/internal/admin/testing" \
  -H 'Content-Type: application/json' \
  -d "{\"sender\":\"$PARTIE\",\"receiver\":\"$PARTIE\"}")
if [ "$CODE_TEST" != "200" ]; then
  echo "❌ Test de connectivité refusé ($CODE_TEST) : $(messageDomibus)" >&2
  exit 1
fi

# Le message part de façon asynchrone : son acquittement se lit ensuite.
#
# Le `|| true` compte ici pour la même raison qu'au-dessus, et trente fois
# plutôt qu'une : une session expirée, une page d'erreur du serveur
# d'applications ou tout corps qui n'est pas du JSON font lever `python3`, et
# `set -e` interromprait le script sur une trace d'appels — au lieu du message
# d'échec ci-dessous, qui, lui, oriente. Le `2>/dev/null` ne masque que cette
# trace : les erreurs de curl, elles, restent affichées.
echo "  message soumis, attente de l'acquittement"
STATUT=""
for _ in $(seq 1 30); do
  sleep 1
  STATUT=$(appelAuthentifie \
    "$URL_DOMIBUS/rest/internal/admin/testing/connectionmonitor?senderPartyId=$PARTIE&partyIds=$PARTIE" \
    | sansPrefixeJSON \
    | python3 -c "
import json, sys
partie = json.load(sys.stdin).get(sys.argv[1]) or {}
print((partie.get('lastSent') or {}).get('messageStatus') or '')
" "$PARTIE" 2> /dev/null || true)
  [ "$STATUT" = "ACKNOWLEDGED" ] && break
  [ "$STATUT" = "SEND_FAILURE" ] && break
done

if [ "$STATUT" != "ACKNOWLEDGED" ]; then
  echo "❌ Le message de test n'a pas été acquitté (statut : ${STATUT:-aucun})." >&2
  echo "   Certificats et alias des profils de sécurité en cause ?" >&2
  echo "   scripts/ci/diagnostiqueDomibus.sh détaille les magasins et les erreurs." >&2
  exit 1
fi


# --------------------------------------------------- notification vers nous
#
# La passerelle nous appelle au lieu d'être interrogée : c'est le *push to
# backend* du plugin WS. Les bascules se posent par l'API, mais **pas les
# règles** : `wsplugin.push.rules` est marquée non modifiable, et n'existe que
# dans le fichier de propriétés du plugin. Elles ne prennent donc effet qu'au
# redémarrage de la passerelle.
#
# Ce fichier s'écrit **depuis le conteneur**, et non depuis l'hôte : la
# passerelle range sa configuration en mode 770, au nom de son propre
# utilisateur. Sur une machine où cet identifiant numérique se trouve être
# celui de l'opérateur, écrire directement fonctionne par coïncidence ;
# ailleurs — un runner d'intégration continue — le fichier n'est même pas
# lisible.
COMMANDE_DOMIBUS="${COMMANDE_DOMIBUS:-docker compose exec -T domibus}"
CONFIG_DOMIBUS="${CONFIG_DOMIBUS:-/data/tomcat/conf/domibus}"
PROPRIETES_PLUGIN="$CONFIG_DOMIBUS/plugins/config/ws-plugin.properties"

if ! $COMMANDE_DOMIBUS test -f "$PROPRIETES_PLUGIN" 2> /dev/null; then
  echo "❌ Fichier de propriétés du plugin introuvable : $PROPRIETES_PLUGIN" >&2
  echo "   Commande employée pour atteindre la passerelle : $COMMANDE_DOMIBUS" >&2
  echo "   La passerelle a-t-elle démarré au moins une fois ? La régler autrement :" >&2
  echo "   COMMANDE_DOMIBUS='docker exec -i <conteneur>' scripts/configureDomibus.sh" >&2
  exit 1
fi

echo "→ Configuration de la notification vers $URL_NOTIFICATION"

# Le bloc est délimité, pour que le script se rejoue sans empiler ses écritures.
# Le fichier livré avec l'image ne finit pas par un saut de ligne : sans le
# `$a\` du sed, le bloc se collerait à sa dernière ligne et son délimiteur ne
# serait plus reconnu au rejeu suivant.
#
# `markAsDownloaded=false` : à `true`, la notification vaut téléchargement, et
# le PMode d'exemple porte `retention_downloaded="0"` — le justificatif serait
# effacé avant que nous l'ayons récupéré. À `false`, c'est notre
# `retrieveMessage` qui marque le message, donc après l'avoir en main.
#
# La règle ne filtre **aucun destinataire** : les messages qui nous arrivent en
# portent deux différents — l'identifiant de la passerelle sur une requête
# entrante, celui du requêteur sur la réponse qui lui revient — et une règle par
# valeur en oublierait toujours une.
#
# `alert.active` vaut `false` par défaut : sans elle, l'épuisement des cinq
# tentatives est parfaitement silencieux. L'alerte paraît dans la console
# d'administration sans configuration supplémentaire ; l'envoi par courriel, lui,
# demanderait un SMTP et les adresses `domibus.alert.{sender,receiver}.email`.
$COMMANDE_DOMIBUS sh -s <<FIN_PROPRIETES
set -e
sed -i '/^# --- OOTS-France/,/^# --- fin OOTS-France\$/d' "$PROPRIETES_PLUGIN"
sed -i -e '\$a\' "$PROPRIETES_PLUGIN"
cat >> "$PROPRIETES_PLUGIN" <<'FIN_BLOC'
# --- OOTS-France : notification vers le dorsal (écrit par configureDomibus.sh)
wsplugin.push.enabled=true
wsplugin.push.markAsDownloaded=false
wsplugin.push.alert.active=true
wsplugin.push.auth.username=$LOGIN_NOTIFICATION_DOMIBUS
wsplugin.push.auth.password=$MOT_DE_PASSE_NOTIFICATION_DOMIBUS
wsplugin.push.rules.oots=Notification de tout message arrivant pour nous
wsplugin.push.rules.oots.endpoint=$URL_NOTIFICATION
wsplugin.push.rules.oots.retry=60;5;CONSTANT
wsplugin.push.rules.oots.type=RECEIVE_SUCCESS
wsplugin.dispatcher.worker.cronExpression=0/5 * * * * ?
# --- fin OOTS-France
FIN_BLOC
FIN_PROPRIETES

echo "  écrit dans $PROPRIETES_PLUGIN — un redémarrage de la passerelle est nécessaire"

echo "✅ Domibus configuré : magasins chargés, PMode chargé, Plugin User $LOGIN_API_REST opérationnel, message de test acquitté"
echo "   Notification vers le dorsal écrite ; redémarrer la passerelle pour qu'elle s'applique."
