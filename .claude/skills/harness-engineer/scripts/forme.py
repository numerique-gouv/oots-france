#!/usr/bin/env python3
"""Measures the shape of the harness files, and checks a cut kept every paragraph.

    forme.py [--depuis AAAA-MM-JJ]         one row per skill or agent, thresholds marked
    forme.py --doublons                    paragraphs found in two files
    forme.py --registre <ancien> [--arbre <dir>]
                                           paragraphs of <ancien> (a path, or rev:path) missing from the tree

Run it from the repository root. It reads nothing but the files under .claude/skills,
.claude/agents and CLAUDE.md; git is asked only for the commit count and for a rev:path.
"""
import argparse
import glob
import os
import re
import subprocess
import sys
import unicodedata

SEUILS = {"lignes": 150, "description": 400, "garde_fous": 5}
DATE = re.compile(r"\b20\d\d-[01]\d-[0-3]\d\b")


def fichiers():
    return sorted(glob.glob(".claude/skills/*/SKILL.md")) + sorted(glob.glob(".claude/agents/*.md"))


def freres(f):
    d = f[: -len("/SKILL.md")] if f.endswith("/SKILL.md") else f[: -len(".md")]
    return sorted(p for p in glob.glob(f"{d}/**/*.md", recursive=True) if p != f)


def lire(source):
    if ":" in source and not os.path.exists(source):
        rev, path = source.split(":", 1)
        return subprocess.run(["git", "show", f"{rev}:{path}"], capture_output=True, text=True, check=True).stdout
    with open(source, encoding="utf-8") as h:
        return h.read()


def frontmatter_et_corps(texte):
    if not texte.startswith("---\n"):
        return "", texte
    fin = texte.index("\n---", 4)
    return texte[4:fin], texte[fin + 4 :]


def description(fm):
    m = re.search(r"^description:\s*(.*?)(?=^\w[\w-]*:|\Z)", fm, re.S | re.M)
    if not m:
        return ""
    return re.sub(r"\s+", " ", m.group(1)).strip().strip('"')


def sur_invocation_seule(fm):
    """`disable-model-invocation: true` retire le skill de la liste de la session : sa description n'est plus chargée."""
    return re.search(r"^disable-model-invocation:\s*true\s*$", fm, re.M) is not None


def paragraphes(texte):
    """Prose paragraphs of at least 60 characters; code blocks and tables are left out."""
    out, bloc, code = [], [], False
    for ligne in texte.splitlines():
        if ligne.startswith("```"):
            code = not code
            continue
        if code or ligne.startswith("|"):
            continue
        if ligne.strip():
            bloc.append(ligne.strip())
        elif bloc:
            out.append(" ".join(bloc))
            bloc = []
    if bloc:
        out.append(" ".join(bloc))
    return [p for p in out if len(p) >= 60 and not p.startswith("#")]


def cle(p):
    p = unicodedata.normalize("NFKD", p).encode("ascii", "ignore").decode()
    p = re.sub(r"^[-*>\d.\s]+", "", p)
    p = re.sub(r"[^a-z0-9]+", " ", p.lower()).strip()
    return p[:40]


def commits(f, depuis):
    r = subprocess.run(["git", "log", "--oneline", f"--since={depuis}", "--", f], capture_output=True, text=True)
    return len(r.stdout.splitlines())


def garde_fous(corps):
    m = re.search(r"^## Garde-fous?\s*$(.*?)(?=^## |\Z)", corps, re.S | re.M)
    return len(re.findall(r"^\s*[-*] ", m.group(1), re.M)) if m else 0


def tableau(depuis):
    print(f"{'fichier':48} {'lignes':>6} {'descr.':>6} {'g.-fous':>7} {'dates':>5} {'commits':>7}  frères (lignes, sommaire si > 100)")
    for f in fichiers():
        texte = lire(f)
        fm, corps = frontmatter_et_corps(texte)
        n = texte.count("\n")
        d = len(description(fm))
        g = garde_fous(corps)
        dates = len(DATE.findall(corps))
        marque = lambda v, s: f"{v}!" if v > s else f"{v} "
        fr = []
        for p in freres(f):
            t = lire(p)
            nl = t.count("\n")
            sommaire = nl <= 100 or bool(re.search(r"^## (Contenu|Sommaire)", t, re.M))
            fr.append(f"{os.path.basename(p)} ({nl}{'' if sommaire else ', sans sommaire!'})")
        print(f"{f:48} {marque(n, SEUILS['lignes']):>6} {marque(d, SEUILS['description']):>6} {marque(g, SEUILS['garde_fous']):>7} {dates:>5} {commits(f, depuis):>7}  {', '.join(fr)}")
    chargees = [f for f in fichiers() if not sur_invocation_seule(frontmatter_et_corps(lire(f))[0])]
    total = sum(len(description(frontmatter_et_corps(lire(f))[0])) for f in chargees)
    mis_de_cote = len(fichiers()) - len(chargees)
    print(f"\ndescriptions chargées à chaque tour : {total} caractères "
          f"({mis_de_cote} sur invocation seule, non comptés)")


def doublons():
    vus = {}
    tous = fichiers() + [p for f in fichiers() for p in freres(f)] + ["CLAUDE.md"]
    for f in tous:
        for p in paragraphes(frontmatter_et_corps(lire(f))[1]):
            vus.setdefault(cle(p), []).append((f, p))
    n = 0
    for k, occ in vus.items():
        if len({f for f, _ in occ}) > 1:
            n += 1
            print(f"« {occ[0][1][:90]}… »")
            for f, _ in occ:
                print(f"    {f}")
    print(f"\n{n} paragraphes présents dans deux fichiers", file=sys.stderr)


def registre(ancien, arbre):
    cles = {}
    for f in glob.glob(f"{arbre}/.claude/**/*.md", recursive=True) + [f"{arbre}/CLAUDE.md", f"{arbre}/CLAUDE.local.md"]:
        if os.path.exists(f):
            for p in paragraphes(frontmatter_et_corps(lire(f))[1]):
                cles.setdefault(cle(p), []).append(f)
    manquants = 0
    for p in paragraphes(frontmatter_et_corps(lire(ancien))[1]):
        if cle(p) not in cles:
            manquants += 1
            print(f"- {p[:120]}")
    print(f"\n{manquants} paragraphes de {ancien} sans équivalent dans {arbre} — chacun doit être justifié dans le commit", file=sys.stderr)
    return manquants


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("--depuis", default="30 days ago")
    a.add_argument("--doublons", action="store_true")
    a.add_argument("--registre")
    a.add_argument("--arbre", default=".")
    args = a.parse_args()
    if args.doublons:
        doublons()
    elif args.registre:
        sys.exit(1 if registre(args.registre, args.arbre) else 0)
    else:
        tableau(args.depuis)
