#!/usr/bin/env python3
"""Résume un rapport SVRL, un fichier à la fois.

Sort en échec si une assertion de rôle FATAL a échoué. Les règles de rôle
CAUTION signalent des slots facultatifs absents (« MAY be present ») : elles
sont affichées en mode bavard mais ne font pas échouer la validation.

Le rapport est lu par un analyseur XML, et non par une expression régulière :
un faux négatif ici passerait pour une validation réussie, ce qui est le pire
verdict qu'un contrôle de conformité puisse rendre.

Appelé par scripts/valideSchematron.sh.
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


def principal():
    rapport, message, regle = sys.argv[1:4]
    bavard = len(sys.argv) > 4 and sys.argv[4] == '--bavard'

    echecs = list(assertionsEchouees(rapport))
    fatales = [e for e in echecs if e['role'] == 'FATAL']
    remarques = [e for e in echecs if e['role'] != 'FATAL']

    if not fatales:
        suffixe = f' ({len(remarques)} slot(s) facultatif(s) absent(s))' if remarques else ''
        print(f'  ✓ {message} / {regle}{suffixe}')
    else:
        print(f'  ✗ {message} / {regle} — {len(fatales)} règle(s) violée(s)')
        for e in fatales:
            print(f'      {e["id"]} : {e["texte"]}')
            if e['emplacement']:
                print(f'          en {e["emplacement"]}')

    if bavard:
        for e in remarques:
            print(f'      [{e["role"]}] {e["id"]} : {e["texte"]}')

    return 1 if fatales else 0


if __name__ == '__main__':
    sys.exit(principal())
