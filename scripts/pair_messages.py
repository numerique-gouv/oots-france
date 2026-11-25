#!/usr/bin/env python3
"""Assemble deux messages ou plus dans le document que lisent les règles de
validation croisée des TDD.

    pair_messages.py <sortie> <nom>=<fichier> [<nom>=<fichier> …]

Les `sch:let` de `OOTS-EDM/crossvalidation/sch/` lisent une racine `Documents`
sans espace de noms, et un `Document` par message, dont l'attribut `name` dit
lequel : `edm-req`, `evidence_response_header`… (`crossvalidation/README.md`
§2.3). Chaque message y est recopié tel quel, prologue XML retiré, et non
réécrit par un analyseur : ses préfixes et ses déclarations d'espaces de noms
restent ceux qu'il a sur le fil.

Le résultat est relu par un analyseur XML avant d'être écrit : un document mal
formé échoue ici, en nommant sa ligne, plutôt que dans Saxon sur la paire.

Appelé par scripts/validate_schematron.sh, en `python3 -I`.
"""
import re
import sys
from xml.dom.minidom import parseString
from xml.sax.saxutils import quoteattr

PROLOGUE = re.compile(r'^\s*<\?xml[^>]*\?>\s*')


def document(nom, chemin):
    with open(chemin, encoding='utf-8') as fichier:
        contenu = PROLOGUE.sub('', fichier.read())

    return f'<Document name={quoteattr(nom)}>\n{contenu.strip()}\n</Document>'


def main(sortie, *paires):
    if not paires:
        sys.exit('Usage : pair_messages.py <sortie> <nom>=<fichier> …')

    documents = [document(*paire.split('=', 1)) for paire in paires]
    assemble = '<?xml version="1.0" encoding="UTF-8"?>\n<Documents>\n' + '\n'.join(documents) + '\n</Documents>\n'
    parseString(assemble.encode('utf-8'))

    with open(sortie, 'w', encoding='utf-8') as fichier:
        fichier.write(assemble)


if __name__ == '__main__':
    main(*sys.argv[1:])
