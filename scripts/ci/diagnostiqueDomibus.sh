#!/bin/sh
# Interroge Domibus après un échec du test e2e, pour savoir ce que la passerelle
# a fait du message.
#
# Les logs Tomcat sont noyés sous les appels de l'écouteur (un par seconde) : ce
# script va chercher l'information utile là où elle est structurée — le journal
# des messages, celui des erreurs, et les certificats réellement chargés.
#
# Usage : scripts/ci/diagnostiqueDomibus.sh
# N'échoue jamais : il ne sert qu'à documenter un échec déjà constaté.

URL_DOMIBUS="${URL_DOMIBUS:-http://localhost:${PORT_DOMIBUS:-8180}/domibus}"
DOMIBUS_ADMIN="${DOMIBUS_ADMIN:-admin}"
DOMIBUS_MOT_DE_PASSE_ADMIN="${DOMIBUS_MOT_DE_PASSE_ADMIN:-123456}"

BOCAL=$(mktemp)
trap 'rm -f "$BOCAL"' EXIT

curl -sS -c "$BOCAL" -o /dev/null \
  -X POST "$URL_DOMIBUS/rest/security/authentication" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$DOMIBUS_ADMIN\",\"password\":\"$DOMIBUS_MOT_DE_PASSE_ADMIN\"}" || exit 0

JETON=$(awk '/XSRF-TOKEN/ { print $7 }' "$BOCAL")

montre() {
  echo
  echo "───────── $1"
  # Le préfixe `)]}',` d'Angular saute avant affichage ; `node` remet en forme
  # ce qui est du JSON et laisse passer le reste tel quel.
  curl -sS -b "$BOCAL" -H "X-XSRF-TOKEN: $JETON" "$URL_DOMIBUS/$2" \
    | tail -c +7 \
    | node -e "
      let e = '';
      process.stdin.on('data', (d) => { e += d; });
      process.stdin.on('end', () => {
        try { console.log(JSON.stringify(JSON.parse(e), null, 2).slice(0, 4000)); }
        catch { console.log(e.slice(0, 2000)); }
      });
    " || echo "(illisible)"
}

montre "Journal des messages" "rest/messagelog?page=0&pageSize=20&orderBy=received&asc=false"
montre "Journal des erreurs" "rest/errorlogs?page=0&pageSize=20&orderBy=timestamp&asc=false"
montre "Certificats du truststore" "rest/truststore/list"

# Domibus 5.0.4 n'expose pas le keystore en REST (venu dans des versions
# ultérieures) : on lit donc directement le magasin monté dans le conteneur.
echo
echo "───────── Certificat de la passerelle (keystore)"
docker compose exec -T domibus \
  keytool -list -keystore /data/tomcat/conf/domibus/keystores/gateway_keystore.jks \
  -storepass "${MOT_DE_PASSE_MAGASINS:-test123}" 2>&1 | head -20 || echo "(illisible)"

exit 0
