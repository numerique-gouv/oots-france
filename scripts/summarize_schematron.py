#!/usr/bin/env python3
"""Résume un rapport SVRL, un fichier à la fois.

Sort en échec si une assertion de rôle FATAL a échoué. Les règles de rôle
CAUTION signalent des slots facultatifs absents (« MAY be present ») : elles
sont affichées en mode bavard mais ne font pas échouer la validation.

`--refus=<règles>` inverse le verdict, pour le spécimen qu'on attend non
conforme : il n'est ✓ que si ce sont exactement ces règles-là qui l'ont refusé.
C'est ce qui prouve qu'une règle mord, ce qu'un spécimen conforme ne dit pas.

Le rapport est lu par un analyseur XML, et non par une expression régulière :
un faux négatif ici passerait pour une validation réussie, ce qui est le pire
verdict qu'un contrôle de conformité puisse rendre.

Appelé par scripts/validate_schematron.sh.
"""
import sys
from xml.etree import ElementTree

SVRL = '{http://purl.oclc.org/dsdl/svrl}'


def assertionsEchouees(rapport):
    racine = ElementTree.parse(rapport).getroot()

    for echec in racine.iter(f'{SVRL}failed-assert'):
        texte = echec.find(f'{SVRL}text')

        yield {
            'role': echec.get('role', 'INCONNU'),
            'id': echec.get('id', '?'),
            'emplacement': echec.get('location', ''),
            'texte': ' '.join((texte.text or '').split()) if texte is not None else '',
        }


def verdictDeConformite(message, regle, fatales, remarques):
    if not fatales:
        suffixe = f' ({len(remarques)} slot(s) facultatif(s) absent(s))' if remarques else ''
        print(f'  ✓ {message} / {regle}{suffixe}')
        return 0

    print(f'  ✗ {message} / {regle} — {len(fatales)} règle(s) violée(s)')
    for e in fatales:
        print(f'      {e["id"]} : {e["texte"]}')
        if e['emplacement']:
            print(f'          en {e["emplacement"]}')

    return 1


def verdictDeRefus(message, regle, fatales, attendues):
    """Verdict inversé, pour un spécimen qu'on attend non conforme.

    Il vaut ✓ si, et seulement si, ce sont exactement les règles nommées qui
    l'ont refusé : un spécimen qui passe ne démontre rien, et un spécimen refusé
    par une règle de plus démontre autre chose que ce qu'on voulait montrer.
    """
    obtenues = {e['id'] for e in fatales}

    if obtenues == attendues:
        print(f'  ✓ {message} / {regle} — refusé par {", ".join(sorted(obtenues))}, comme attendu')
        return 0

    print(f'  ✗ {message} / {regle} — refus attendu de {", ".join(sorted(attendues))}')
    for identifiant in sorted(attendues - obtenues):
        print(f'      {identifiant} n\'a pas refusé le spécimen')
    for e in fatales:
        if e['id'] not in attendues:
            print(f'      {e["id"]} a refusé en plus : {e["texte"]}')

    return 1


def reglesAttendues(options):
    """`--refus=R-EDM-ebMS-017,R-EDM-ebMS-037`, ou None hors validation négative.

    Une liste jointe par des virgules plutôt que des arguments qui suivent :
    l'option reste alors placée n'importe où, à côté de `--bavard`.
    """
    for option in options:
        if option.startswith('--refus='):
            return set(option.removeprefix('--refus=').split(','))

    return None


def principal():
    rapport, message, regle = sys.argv[1:4]
    options = sys.argv[4:]
    bavard = '--bavard' in options
    attendues = reglesAttendues(options)

    echecs = list(assertionsEchouees(rapport))
    fatales = [e for e in echecs if e['role'] == 'FATAL']
    remarques = [e for e in echecs if e['role'] != 'FATAL']

    if attendues is None:
        code = verdictDeConformite(message, regle, fatales, remarques)
    else:
        code = verdictDeRefus(message, regle, fatales, attendues)

    if bavard:
        for e in remarques:
            print(f'      [{e["role"]}] {e["id"]} : {e["texte"]}')

    return code


if __name__ == '__main__':
    sys.exit(principal())
