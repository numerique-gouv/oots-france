#!/usr/bin/env python3
"""Rereads a ticket draft the way a contradicteur would, for what a script can settle.

    relire-le-jet.py <jet.md> [--base <commit>]

Run it from the repository root, on the draft file, before the first contradicteur pass
and after every correction. It is a reading aid, not a gate: it prints five sections and
spec-nerd decides what each item is worth.

    FORME    what gabarit-issue.md fixes: title, header, sections, numbering, RG <-> CA
             coverage, bare identifiers and bare URLs
    RÈGLES   every Schematron rule the draft cites, with its role, context and test read
             from .schematron/<version>/sch/ — an id that resolves nowhere is flagged
    DÉPÔT    every repository path the draft cites, with whether it exists and, when a
             line is given, whether the file is that long
    VOISINS  every ticket the draft cites — to reopen with get_issue in the pass
    BASE     what moved on main since the base commit, on the cited paths and overall

It reads the draft, the .schematron tree and git; it never touches Linear, so VOISINS is a
list, not a verdict. It always exits 0.
"""
import argparse
import glob
import os
import re
import subprocess
import sys

SECTIONS = ["Contexte", "Règles de gestion", "Critères d'acceptance", "Hors périmètre", "Vérification"]
EN_TETE = ["Chapitre", "Acteur", "Priorité", "Description"]
REGLE = re.compile(r"R-EDM-(REQ|RESP|ERR)-([CS])(\d{3})")
REGLE_COURTE = re.compile(r"`([CS])(\d{3})`")
CHEMIN = re.compile(
    r"`((?:app|config|db|docs|features|lib|scripts|spec|\.schematron|\.claude)/[^`\s:]+)(?::(\d+)(?:-\d+)?)?`"
)
CHEMIN_GITHUB = re.compile(r"github\.com/numerique-gouv/oots-france/blob/[^/]+/([^)\s#>]+)")
TICKET = re.compile(r"OOTS-\d+")
TICKET_LIE = re.compile(r"\[OOTS-\d+\]\(https://linear\.app/[^)]+\)")
URL_NUE = re.compile(r"(?<![(<`])https?://[^\s)>`]+")
BASE = re.compile(r"Spécifié contre `main` à `?([0-9a-f]{7,40})`?")


def sections(texte):
    """Returns {title: body} for every '## ' section, in order of appearance."""
    parts = re.split(r"^## (.+)$", texte, flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


def lignes_tableau(corps, prefixe):
    return re.findall(rf"^\| ({prefixe}\d+) \|(.*)$", corps, re.M)


def forme(texte):
    constats = []
    titre = next((l for l in texte.splitlines() if l.strip()), "")
    if not re.match(r"#?\s*US - \S", titre):
        constats.append(f"le titre ne commence pas par `US - ` : « {titre[:80]} »")
    for label in EN_TETE:
        if not re.search(rf"^\| \*\*{label}\*\* \|", texte, re.M):
            constats.append(f"l'en-tête n'a pas de ligne `{label}`")
    description = re.search(r"^\| \*\*Description\*\* \|(.*)\|", texte, re.M)
    if description and not re.search(r"En tant qu\S*\s*\*\*.+\*\*.*je dois \*\*.+\*\*.*afin qu\S*\s*\*\*.+\*\*", description.group(1)):
        constats.append("la description n'a pas ses trois segments en gras, *En tant que / je dois / afin que*, dans cet ordre")
    secs = sections(texte)
    presentes = [s for s in SECTIONS if s in secs]
    attendues = [s for s in SECTIONS if s in secs or s != "Contexte"]
    if presentes != [s for s in attendues if s in secs] or [s for s in secs if s in SECTIONS] != presentes:
        constats.append(f"les sections ne sont pas dans l'ordre du gabarit : {list(secs)}")
    for s in SECTIONS[1:]:
        if s not in secs:
            constats.append(f"la section `## {s}` manque")
        elif not secs[s].strip():
            constats.append(f"la section `## {s}` est vide")
    for inconnue in [s for s in secs if s not in SECTIONS]:
        constats.append(f"la section `## {inconnue}` n'est pas dans le gabarit")
    rgs = lignes_tableau(secs.get("Règles de gestion", ""), "RG")
    cas = lignes_tableau(secs.get("Critères d'acceptance", ""), "CA")
    for prefixe, lignes in (("RG", rgs), ("CA", cas)):
        numeros = [int(n[len(prefixe):]) for n, _ in lignes]
        if numeros != list(range(1, len(numeros) + 1)):
            constats.append(f"la numérotation des {prefixe} a un trou ou un désordre : {numeros}")
    connues = {n for n, _ in rgs}
    couvertes = set()
    for ca, reste in cas:
        colonnes = [c.strip() for c in reste.split("|")]
        derniere = colonnes[-2] if len(colonnes) >= 2 else ""
        citees = set(re.findall(r"RG\d+", derniere))
        if not citees:
            constats.append(f"{ca} ne nomme aucune RG dans sa dernière colonne")
        for rg in citees - connues:
            constats.append(f"{ca} nomme {rg}, qui n'existe pas")
        couvertes |= citees
        if not re.search(r"\*\*Étant donné\*\*.*\*\*[Ll]orsque\*\*.*\*\*[Aa]lors\*\*", reste):
            constats.append(f"{ca} n'a pas ses trois temps en gras, *Étant donné / Lorsque / Alors*")
    for rg in sorted(connues - couvertes, key=lambda r: int(r[2:])):
        constats.append(f"{rg} n'est prouvée par aucun CA")
    for ticket in sorted(set(TICKET.findall(TICKET_LIE.sub("", texte)))):
        constats.append(f"{ticket} est cité nu quelque part ; un ticket se cite en lien, `[{ticket}](https://linear.app/pole-api/issue/{ticket})`")
    prose = re.sub(r"```.*?```", "", texte, flags=re.S)
    prose = re.sub(r"`[^`\n]*`", "", prose)
    for url in sorted(set(URL_NUE.findall(prose)))[:10]:
        constats.append(f"URL nue dans la prose : {url[:90]}")
    return constats


def regles(texte):
    """Resolves every cited rule against the .sch files; short forms take the family of the nearest full id before them."""
    cibles = {}
    for m in REGLE.finditer(texte):
        cibles[m.group(0)] = m.start()
    famille = None
    for m in REGLE_COURTE.finditer(texte):
        avant = [(p, r) for r, p in cibles.items() if p < m.start()]
        famille = max(avant)[1].rsplit("-", 1)[0] if avant else famille
        if famille:
            cibles.setdefault(f"{famille}-{m.group(1)}{m.group(2)}", m.start())
    resolues, absentes = [], []
    versions = sorted(glob.glob(".schematron/*/sch")) or sorted(glob.glob(f"{racine_principale()}/.schematron/*/sch"))
    index = {}
    for dossier in versions:
        for fichier in glob.glob(f"{dossier}/*.sch"):
            contenu = open(fichier, encoding="utf-8").read()
            contexte = None
            for morceau in re.finditer(r"<sch:rule context=\"([^\"]+)\"|<sch:assert\s+(.*?)>", contenu, re.S):
                if morceau.group(1):
                    contexte = morceau.group(1)
                    continue
                attributs = {k: a or b for k, a, b in re.findall(r"(\w+)=(?:\"([^\"]*)\"|'([^']*)')", morceau.group(2))}
                if "id" in attributs:
                    index.setdefault(attributs["id"], []).append(
                        (os.path.basename(os.path.dirname(dossier)), attributs.get("role", "?"), contexte or "?", attributs.get("test", "?"))
                    )
    for regle in sorted(cibles, key=cibles.get):
        if regle in index:
            for version, role, contexte, test in index[regle]:
                resolues.append(f"{regle} @ {version} — {role} — contexte `{contexte}` — test `{test[:160]}`")
        else:
            absentes.append(f"{regle} n'est dans aucun `.sch` de {', '.join(versions) or '.schematron/, absent : `scripts/validate_schematron.sh 2.0.1` le remplit'}")
    if "1.2.5" in texte and not any("1.2.5" in v for v in versions):
        absentes.append("le jet cite la ligne 1.2.5, dont le `.sch` n'est pas dans le dépôt : chaque règle qu'il lui prête se lit en amont (docs/carte_des_tdd.md dit où)")
    return resolues, absentes


def racine_principale():
    """The main checkout: .schematron/ is git-ignored, so a worktree does not carry it."""
    commun = subprocess.run(["git", "rev-parse", "--git-common-dir"], capture_output=True, text=True).stdout.strip()
    return os.path.dirname(os.path.abspath(commun)) if commun else "."


def depot(texte):
    constats, ouverts = [], []
    cites = {m.group(1): m.group(2) for m in CHEMIN.finditer(texte)}
    for chemin in CHEMIN_GITHUB.findall(texte):
        cites.setdefault(chemin, None)
    for chemin, ligne in sorted(cites.items()):
        if not os.path.exists(chemin):
            constats.append(f"`{chemin}` n'existe pas dans le dépôt")
            continue
        if ligne and os.path.isfile(chemin):
            total = sum(1 for _ in open(chemin, encoding="utf-8", errors="replace"))
            if int(ligne) > total:
                constats.append(f"`{chemin}:{ligne}` : le fichier n'a que {total} lignes")
                continue
        ouverts.append(chemin)
    return constats, ouverts


def base_bougee(base, chemins):
    if not base:
        return ["aucune base : le jet ne porte pas « Spécifié contre `main` à `<commit>` », et rien ne dira ce qui a bougé sous lui"]
    def git(*args):
        return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()
    if not git("cat-file", "-t", base):
        return [f"la base `{base}` n'est pas un commit connu du dépôt"]
    total = git("rev-list", "--count", f"{base}..HEAD")
    lignes = [f"{total} commit(s) sur `main` depuis `{base}`"]
    if chemins and total != "0":
        touches = git("log", "--oneline", f"{base}..HEAD", "--", *chemins)
        lignes.append("sur les chemins cités : " + (touches.replace("\n", " ; ") if touches else "rien"))
    return lignes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("jet")
    parser.add_argument("--base", help="commit de main contre lequel le jet est écrit (par défaut, lu dans le jet)")
    args = parser.parse_args()
    texte = open(args.jet, encoding="utf-8").read()
    base = args.base or (BASE.search(texte).group(1) if BASE.search(texte) else None)

    f = forme(texte)
    resolues, absentes = regles(texte)
    d, ouverts = depot(texte)
    voisins = sorted(set(TICKET.findall(texte)), key=lambda t: int(t[5:]))

    def section(titre, items, vide):
        print(f"\n== {titre} ==")
        print("\n".join(f"- {i}" for i in items) if items else vide)

    section("FORME — ce qui s'écarte du gabarit", f, "rien : le jet a la forme du gabarit")
    section("RÈGLES — ce que chaque règle citée dit vraiment", resolues + absentes, "aucune règle Schematron citée")
    section("DÉPÔT — chemins cités", d + [f"`{c}` existe — ce que le jet en dit se relit dedans" for c in ouverts], "aucun chemin du dépôt cité")
    section("VOISINS — tickets cités, à rouvrir par get_issue dans la passe", voisins, "aucun ticket cité")
    section("BASE — ce qui a bougé sous le jet", base_bougee(base, ouverts), "")


if __name__ == "__main__":
    main()
