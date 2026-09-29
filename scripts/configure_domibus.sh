#!/bin/sh
# Configures a fresh Domibus instance, without going through the web console.
#
# Reproduces the steps described in the README (load the PMode, create the Plugin
# User) through the administration REST API, so that continuous integration can
# raise a usable gateway with no human intervention.
#
# Usage: scripts/configure_domibus.sh
#
# Recognised variables (defaults in brackets):
#   URL_DOMIBUS                 console URL; failing that, PORT_DOMIBUS composes
#                               http://localhost:${PORT_DOMIBUS:-8180}/domibus
#   DOMIBUS_ADMIN               console admin account (admin)
#   DOMIBUS_MOT_DE_PASSE_ADMIN  console password (123456)
#   LOGIN_API_REST              Plugin User to create — mandatory
#   MOT_DE_PASSE_API_REST       its password — mandatory, 16 to 32 characters,
#                               with an upper case, a lower case, a digit and a
#                               special character, failing which Domibus refuses
#                               it
#   LOGIN_NOTIFICATION_DOMIBUS  the credentials the gateway puts on the
#   MOT_DE_PASSE_NOTIFICATION_DOMIBUS
#                               notifications it pushes at us — mandatory, and
#                               having to match the ones in .env.oots, which the
#                               application checks them against
#
# Those two credentials must be the ones in the .env.oots the application runs
# with: this is the account it will present to the gateway. They are required
# rather than derived, a .env.oots not being sourceable from a shell script — its
# values contain `&` and JSON braces.
#   FICHIER_PMODE               PMode to load (exemples/configuration_PMode_Domibus.xml)
#   REPERTOIRE_KEYSTORE_TRUSTSTORE
#                               where to read keystore and truststore; failing
#                               that, they are generated into a temporary
#                               directory by scripts/generate_certificates.sh
#   MOT_DE_PASSE_KEYSTORE_TRUSTSTORE
#                               their password — mandatory, and having to match
#                               the one in the .env the gateway runs with
#   PORT_OOTS_FRANCE            the port `web` listens on, out of which the
#                               notification address towards us is composed —
#                               mandatory, and having to match the one in the
#                               .env the stack runs with, since a worktree shifts
#                               it; URL_NOTIFICATION overrides the whole address

set -e

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DOMIBUS_ADMIN="${DOMIBUS_ADMIN:-admin}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-123456}"
LOGIN_API_REST="${LOGIN_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
MOT_DE_PASSE_API_REST="${MOT_DE_PASSE_API_REST:?doit être renseigné, et correspondre à celui de .env.oots}"
FICHIER_PMODE="${FICHIER_PMODE:-exemples/configuration_PMode_Domibus.xml}"
MOT_DE_PASSE_KEYSTORE_TRUSTSTORE="${MOT_DE_PASSE_KEYSTORE_TRUSTSTORE:?doit être renseigné, et correspondre à celui de .env}"
PARTIE="AP_FR_01"

# The directory mounted into the gateway, where the plugin's properties live.
REPERTOIRE_DOMIBUS="${REPERTOIRE_DOMIBUS:-domibus}"

# The address the gateway notifies us at, and the credentials it will put on
# those calls. Seen from the Domibus container, hence the service name.
#
# The port is the one `web` listens on, which is `PORT_OOTS_FRANCE` and not a
# fixed 3000: a worktree shifts it, and a gateway configured on 3000 would push
# the correspondent's answers at a port nothing listens on — silently, the page
# that follows the exchange staying on « en cours » for ever.
URL_NOTIFICATION="${URL_NOTIFICATION:-http://web:${PORT_OOTS_FRANCE:?doit être renseigné, et correspondre à celui de .env}/domibus/notifications}"
LOGIN_NOTIFICATION_DOMIBUS="${LOGIN_NOTIFICATION_DOMIBUS:?doit être renseigné, et correspondre à celui de .env.oots}"
MOT_DE_PASSE_NOTIFICATION_DOMIBUS="${MOT_DE_PASSE_NOTIFICATION_DOMIBUS:?doit être renseigné, et correspondre à celui de .env.oots}"

BOCAL=$(mktemp)
REPONSE=$(mktemp)
PMODE_CHARGE=$(mktemp)
trap 'rm -f "$BOCAL" "$REPONSE" "$PMODE_CHARGE"' EXIT

# The API's responses are prefixed with `)]}',` (Angular's protection against
# JSON hijacking): that prefix must go before any parsing.
sansPrefixeJSON() { tail -c +7; }

echo "→ Authentification sur $URL_DOMIBUS en tant que $DOMIBUS_ADMIN"
if ! curl -sS -f -c "$BOCAL" -o /dev/null \
  -X POST "$URL_DOMIBUS/rest/public/security/authentication" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$DOMIBUS_ADMIN\",\"password\":\"$DOMIBUS_MOT_DE_PASSE_ADMIN\"}"; then
  echo "❌ Authentification refusée sur $URL_DOMIBUS (passerelle joignable ? identifiants ?)." >&2
  exit 1
fi

# The anti-CSRF token is dropped as a cookie and must be sent back as a header
# on every modifying request.
JETON=$(awk '/XSRF-TOKEN/ { print $7 }' "$BOCAL")
if [ -z "$JETON" ]; then
  echo "❌ Aucun jeton XSRF reçu : authentification refusée ?" >&2
  exit 1
fi

appelAuthentifie() {
  curl -sS -b "$BOCAL" -H "X-XSRF-TOKEN: $JETON" "$@"
}

# Makes an authenticated call, puts the response body into $REPONSE and returns
# the HTTP code. Domibus explains its refusals in that body, which the failure
# messages relay.
#
# The `|| true` is indispensable: on a network error curl exits in failure, and
# `set -e` would interrupt the script in the middle of a substitution — before
# the message that explains what happened. curl then writes `000`, which the code
# comparisons treat like any other refusal.
appelAvecCode() {
  appelAuthentifie -o "$REPONSE" -w '%{http_code}' "$@" || true
}

# The `)]}',` prefix caps the console's JSON responses only: an application
# server error page has none, and would lose six bytes if it were stripped
# without looking.

messageDomibus() {
  if head -c 6 "$REPONSE" 2> /dev/null | grep -qF ")]}',"; then
    tail -c +7 "$REPONSE" | head -c 500
  else
    head -c 500 "$REPONSE" 2> /dev/null
  fi
}

# Chapter 4.7 has the PartyId and its type processed case-sensitively, and the
# rest of this script names our party by that same string: a PMode that declares
# it otherwise — one the Technical Support Dashboard generated, say — is refused
# here, before anything is uploaded, rather than surfacing as a message never
# acknowledged.
#
# The Technical Support Dashboard generates one PMode for the whole network,
# with every process of it: lcmProcess lists the access points declared for LCM,
# which ours is not.
# Domibus 5.2 refuses a PMode where its own party takes part in a process neither
# as initiator nor as responder (BusinessProcessValidator, DOM_003), so such
# processes are dropped from what is uploaded. None carries a message ours sends
# or receives; the file on disk is left as published.
echo "→ Vérification de la partie $PARTIE dans $FICHIER_PMODE"
if ! python3 - "$FICHIER_PMODE" "$PARTIE" "$PMODE_CHARGE" <<'PYTHON'
import shutil
import sys
import xml.etree.ElementTree as ET

fichier, partie, sortie = sys.argv[1], sys.argv[2], sys.argv[3]
arbre = ET.parse(fichier)
local = lambda element: element.tag.rsplit('}', 1)[-1]

declarees = [
    (element.get('name'), identifiant.get('partyId'))
    for element in arbre.iter()
    if local(element) == 'party'
    for identifiant in element
    if local(identifiant) == 'identifier'
]
if (partie, partie) not in declarees:
    proches = [d for d in declarees if partie.lower() in (str(d[0]).lower(), str(d[1]).lower())]
    print(f"❌ Aucune partie nommée {partie} et d'identifiant {partie}, à la casse près, dans {fichier}.", file=sys.stderr)
    if proches:
        print('   Déclarées à la casse près (nom, partyId) : ' + ', '.join(map(str, proches)), file=sys.stderr)
    sys.exit(1)

retires = []
for parent in list(arbre.iter()):
    for process in [e for e in parent if local(e) == 'process']:
        participants = {
            e.get('name') for e in process.iter()
            if local(e) in ('initiatorParty', 'responderParty')
        }
        if partie not in participants:
            parent.remove(process)
            retires.append(process.get('name'))

if retires:
    racine = arbre.getroot()
    if racine.tag.startswith('{'):
        ET.register_namespace('db', racine.tag[1:].split('}')[0])
    arbre.write(sortie, encoding='UTF-8', xml_declaration=True)
    print(f"  processus sans {partie}, retirés du PMode chargé : {', '.join(retires)}")
else:
    shutil.copyfile(fichier, sortie)
PYTHON
then
  exit 1
fi

# The certificates shipped with the image are public and shared by every
# installation: ours are imposed instead. Where no stores are supplied they are
# generated — they need not outlive the script, the gateway keeping them in its
# database once uploaded.
if [ -z "$REPERTOIRE_KEYSTORE_TRUSTSTORE" ]; then
  REPERTOIRE_KEYSTORE_TRUSTSTORE=$(mktemp -d)
  trap 'rm -f "$BOCAL" "$REPONSE" "$PMODE_CHARGE"; rm -rf "$REPERTOIRE_KEYSTORE_TRUSTSTORE"' EXIT
  echo "→ Génération du keystore et du truststore dans $REPERTOIRE_KEYSTORE_TRUSTSTORE"
  DESTINATION="$REPERTOIRE_KEYSTORE_TRUSTSTORE" MOT_DE_PASSE_KEYSTORE_TRUSTSTORE="$MOT_DE_PASSE_KEYSTORE_TRUSTSTORE" \
    "$(dirname "$0")/generate_certificates.sh" > /dev/null
fi

# Both stores are laid down through the same API since Domibus 5.1: the detour
# taking the keystore through the disk, which 5.0.4 imposed, has no place any
# more.
#
# allowChangingDiskStoreProps lets Domibus align its store properties on the file
# it receives. It does so for the truststore alone — the keystore's type and
# location are forced at start-up, see docker-compose.yml.
chargeStore() {
  storeNom="$1"
  storeFichier="$REPERTOIRE_KEYSTORE_TRUSTSTORE/gateway_$1.p12"

  if [ ! -f "$storeFichier" ]; then
    echo "❌ Fichier introuvable : $storeFichier" >&2
    exit 1
  fi

  echo "→ Chargement du $storeNom $storeFichier"
  # --form-string rather than -F for the values: -F treats a leading `@` or `<`
  # as a filename to read, which would send its contents in place of the
  # password. The store itself is the only real file here.
  storeCode=$(appelAvecCode \
    -F "file=@$storeFichier" \
    --form-string "password=$MOT_DE_PASSE_KEYSTORE_TRUSTSTORE" \
    --form-string "allowChangingDiskStoreProps=true" \
    "$URL_DOMIBUS/rest/internal/admin/$storeNom/save")
  if [ "$storeCode" != "200" ]; then
    echo "❌ Chargement du $storeNom refusé ($storeCode) : $(messageDomibus)" >&2
    exit 1
  fi
}

chargeStore truststore
chargeStore keystore

# Stores generated before the gateway left Domibus's security profiles hold
# AP_FR_01_rsa_sign and AP_FR_01_rsa_decrypt, and generate_certificates.sh
# refuses to overwrite them: uploaded again, they leave the gateway without the
# key docker-compose.yml names. Java store aliases being case-insensitive, so is
# the comparison.
echo "→ Vérification de la clé $PARTIE dans le keystore"
ALIAS_CLES=$(appelAuthentifie "$URL_DOMIBUS/rest/internal/admin/keystore/list" \
  | sansPrefixeJSON \
  | python3 -c "
import json, sys
print(' '.join(entree.get('name', '') for entree in json.load(sys.stdin).get('trustStoreList') or []))
" 2> /dev/null || true)
if ! printf '%s\n' $ALIAS_CLES | grep -qix "$PARTIE"; then
  echo "❌ Le keystore chargé n'a pas de clé $PARTIE (alias : ${ALIAS_CLES:-aucun})." >&2
  echo "   Un keystore d'avant le mode legacy ? Supprimer $REPERTOIRE_KEYSTORE_TRUSTSTORE/*.p12," >&2
  echo "   relancer scripts/generate_certificates.sh, puis ce script." >&2
  exit 1
fi

echo "→ Chargement du PMode $FICHIER_PMODE"
# Domibus answers 200 while reporting the PMode's warnings: those of the example
# PMode (identical initiator and responder roles) are expected, the gateway
# talking to itself. The file sent is the temporary copy, whose name curl cannot
# infer a type from: Domibus refuses anything but XML (DOM_001), hence the type
# and name given explicitly.
CODE_PMODE=$(appelAvecCode \
  -F "file=@$PMODE_CHARGE;filename=$(basename "$FICHIER_PMODE");type=text/xml" \
  --form-string "description=Configuration automatique" \
  "$URL_DOMIBUS/rest/internal/admin/pmode")
if [ "$CODE_PMODE" != "200" ]; then
  echo "❌ Chargement du PMode refusé ($CODE_PMODE) : $(messageDomibus)" >&2
  exit 1
fi

# Recreating an existing Plugin User fails: one is created only where missing, so
# that the script can be replayed without error.
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

# First guard rail: it is through this account, and on this route, that the
# application resolves access points. If it fails here, it will fail in the
# test.
echo "→ Vérification de l'accès à l'annuaire des parties"
CODE_PARTIE=$(curl -sS -o /dev/null -w '%{http_code}' \
  -u "$LOGIN_API_REST:$MOT_DE_PASSE_API_REST" \
  "$URL_DOMIBUS/ext/party?name=$PARTIE" || true)
if [ "$CODE_PARTIE" != "200" ]; then
  echo "❌ L'annuaire des parties répond $CODE_PARTIE au Plugin User $LOGIN_API_REST." >&2
  exit 1
fi

# Second guard rail, far more telling: the console's connectivity test — the
# "paper plane". It circulates a real AS4 message in a loop through the gateway,
# so it exercises signing and encryption, and validates the aliases of both
# stores along the way. All of it owing nothing to the application: if it passes
# and the end-to-end test fails, the gateway is out of the picture.
echo "→ Test de connectivité $PARTIE → $PARTIE"
CODE_TEST=$(appelAvecCode \
  -X POST "$URL_DOMIBUS/rest/internal/admin/testing" \
  -H 'Content-Type: application/json' \
  -d "{\"sender\":\"$PARTIE\",\"receiver\":\"$PARTIE\"}")
if [ "$CODE_TEST" != "200" ]; then
  echo "❌ Test de connectivité refusé ($CODE_TEST) : $(messageDomibus)" >&2
  exit 1
fi

# The message leaves asynchronously: its acknowledgement is read afterwards.
#
# The `|| true` counts here for the same reason as above, and thirty times rather
# than once: an expired session, an application server error page or any body
# that is not JSON makes `python3` raise, and `set -e` would interrupt the script
# on a traceback — instead of the failure message below, which does point
# somewhere. The `2>/dev/null` masks that traceback alone: curl's own errors stay
# on screen.
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
  echo "   Certificats ou alias du keystore et du truststore en cause ?" >&2
  echo "   scripts/ci/diagnose_domibus.sh détaille le keystore, le truststore et les erreurs." >&2
  exit 1
fi


# ------------------------------------------------- notification towards us
#
# The gateway calls us instead of being polled: this is the WS plugin's *push to
# backend*. The switches are set through the API, but **not the rules**:
# `wsplugin.push.rules` is marked non-writable, and exists only in the plugin's
# properties file. They therefore take effect only when the gateway restarts.
#
# That file is written **from inside the container**, and not from the host: the
# gateway stores its configuration in mode 770, owned by its own user. On a
# machine where that numeric id happens to be the operator's, writing directly
# works by coincidence; elsewhere — a continuous integration runner — the file is
# not even readable.
COMMANDE_DOMIBUS="${COMMANDE_DOMIBUS:-docker compose exec -T domibus}"
CONFIG_DOMIBUS="${CONFIG_DOMIBUS:-/data/tomcat/conf/domibus}"
PROPRIETES_PLUGIN="$CONFIG_DOMIBUS/plugins/config/ws-plugin.properties"

if ! $COMMANDE_DOMIBUS test -f "$PROPRIETES_PLUGIN" 2> /dev/null; then
  echo "❌ Fichier de propriétés du plugin introuvable : $PROPRIETES_PLUGIN" >&2
  echo "   Commande employée pour atteindre la passerelle : $COMMANDE_DOMIBUS" >&2
  echo "   La passerelle a-t-elle démarré au moins une fois ? La régler autrement :" >&2
  echo "   COMMANDE_DOMIBUS='docker exec -i <conteneur>' scripts/configure_domibus.sh" >&2
  exit 1
fi

echo "→ Configuration de la notification vers $URL_NOTIFICATION"

# The block is delimited, so the script replays without stacking its writes.
# Each range carries the whole start marker of its own generation, the earlier
# French one included: a file holding one generation's block is then never
# entered by the other generation's range, which — finding no end marker of its
# own — would run to the end of the file.
#
# The file shipped with the image does not end in a newline: without the sed's
# `$a\`, the block would stick to its last line and its delimiter would no longer
# be recognised on the next replay.
#
# `markAsDownloaded=false`: at `true`, the notification counts as a download, and
# the example PMode carries `retention_downloaded="0"` — the evidence would be
# erased before we had retrieved it. At `false`, it is our own `retrieveMessage`
# that marks the message, and so only once we hold it.
#
# The rule filters **no recipient**: the messages that reach us carry two
# different ones — the gateway's identifier on an incoming request, the
# requester's on the response that comes back to it — and one rule per value
# would always forget one.
#
# `alert.active` is `false` by default: without it, exhausting the five attempts
# is perfectly silent. The alert appears in the administration console with no
# further configuration; sending it by email would take an SMTP server and the
# addresses `domibus.alert.{sender,receiver}.email`.
$COMMANDE_DOMIBUS sh -s <<FIN_PROPRIETES
set -e
sed -i -e '/^# --- OOTS-France : notification vers le dorsal/,/^# --- fin OOTS-France\$/d' \
       -e '/^# --- OOTS-France: push to backend/,/^# --- end OOTS-France\$/d' "$PROPRIETES_PLUGIN"
sed -i -e '\$a\' "$PROPRIETES_PLUGIN"
cat >> "$PROPRIETES_PLUGIN" <<'FIN_BLOC'
# --- OOTS-France: push to backend (written by configure_domibus.sh)
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
# --- end OOTS-France
FIN_BLOC
FIN_PROPRIETES

echo "  écrit dans $PROPRIETES_PLUGIN — un redémarrage de la passerelle est nécessaire"

echo "✅ Domibus configuré : keystore et truststore chargés, PMode chargé, Plugin User $LOGIN_API_REST opérationnel, message de test acquitté"
echo "   Notification vers le dorsal écrite ; redémarrer la passerelle pour qu'elle s'applique."
