#!/usr/bin/env bash
# Declares the Austrian access point in a PMode under the party id type its
# gateway and the DSD use, urn:cef.eu:names:identifier:EAS:9915, where the
# Technical Support Dashboard publishes urn:oasis:names:tc:ebcore:partyid-type:unregistered:AT.
#
# Chapter 4.7 § 2.2, table 1, takes PMode[].Responder.Party/@type from the DSD's
# AccessService/Identifier/@schemeID, and Domibus matches a party on its id and
# type together: with the published PMode, a request to Austria dies in BUS-075
# and Austria's messages to France in EBMS:0003.
#
# Usage: scripts/fix_austria_pmode.sh [PMode file]   (default: domibus/AP_FR_01.xml)
#
# Rewrites the file in place, a copy kept beside it; loading it into the gateway
# is scripts/configure_domibus.sh's job, with FICHIER_PMODE naming the file.
set -euo pipefail

pmode="${1:-domibus/AP_FR_01.xml}"
party='SDG-OOP-AT-SCONAP-Q'
published_type='urn:oasis:names:tc:ebcore:partyid-type:unregistered:AT'
dsd_type='urn:cef.eu:names:identifier:EAS:9915'

[ -f "$pmode" ] || { echo "❌ $pmode introuvable" >&2; exit 1; }

identifier_under() { grep -qE "<identifier[^>]*partyId=\"$party\"[^>]*partyIdType=\"$1\"" "$pmode"; }
type_declared() { grep -q "<partyIdType name=\"$dsd_type\"" "$pmode"; }

if identifier_under "$dsd_type" && type_declared; then
  echo "✅ $pmode déjà corrigé : $party sous $dsd_type"
  exit 0
fi

identifier_under "$published_type" || {
  echo "❌ Aucun identifiant $party sous $published_type dans $pmode : le PMode a changé, à regarder à la main" >&2
  grep -n "$party" "$pmode" >&2 || true
  exit 1
}

backup="$pmode.avant-autriche-$(date +%Y%m%d-%H%M%S)"
cp -p "$pmode" "$backup"

restore() {
  cp -p "$backup" "$pmode"
  echo "❌ $1 : fichier restauré depuis $backup" >&2
  exit 1
}

# Domibus refuses one partyId declared twice, whatever the types
# (PartyIdentifierValidator): the existing identifier changes type, none is added.
sed -i -E "s#(<identifier[^>]*partyId=\"$party\"[^>]*partyIdType=\")$published_type(\")#\1$dsd_type\2#" "$pmode"

# The published PMode has CRLF line endings, which the inserted line reproduces.
type_declared || sed -i -E "s#^([[:space:]]*)(<partyIdType name=\"$published_type\"[^>]*/>)(\r?)\$#\1\2\3\n\1<partyIdType name=\"$dsd_type\" value=\"$dsd_type\"/>\3#" "$pmode"

python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$pmode" || restore "XML invalide après correction"
identifier_under "$dsd_type" && type_declared || restore "Correction incomplète"

echo "✅ $pmode corrigé (copie : $backup)"
diff "$backup" "$pmode" || true
echo
echo "Reste à le charger, le mot de passe entre apostrophes simples :"
echo "  DOMIBUS_MOT_DE_PASSE_ADMIN='…' FICHIER_PMODE=$pmode scripts/configure_domibus.sh"
echo "  docker compose restart domibus && scripts/ci/wait_for_domibus.sh"
