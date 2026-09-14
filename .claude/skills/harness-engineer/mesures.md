# Mesures

Lu aux étapes 2, 7 et 9 de la passe. Chaque chiffre d'un audit vient d'une de ces commandes, ou d'un script nommé ici ; un chiffre qu'aucune commande ne rend n'entre pas dans un constat. Les bases datées sont dans les audits, jamais ici.

## Contenu

- La forme du harnais (`forme.py`)
- Les fichiers de l'atelier
- Les jetons par poste
- M1 à M7 — l'impact d'une découpe
- Contrôles

## La forme du harnais

```sh
python3 .claude/skills/harness-engineer/scripts/forme.py --depuis "$DEPUIS"   # une ligne par skill et par agent, `!` sur un seuil franchi
python3 .claude/skills/harness-engineer/scripts/forme.py --doublons           # les paragraphes présents dans deux fichiers
```

Les seuils qu'il applique sont ceux de `comment-on-ecrit.md` : 150 lignes, 400 caractères de description, 5 garde-fous, sommaire au-delà de 100 lignes pour un frère.

## Les fichiers de l'atelier

```sh
# passes par PR : une section « # Passe n » par passe dans le fichier de la PR ; les suffixes -2, -3… sont la forme d'avant le 2026-09-08, que les fichiers existants gardent
for s in $(ls .claude/reviews | sed -E 's/-[0-9]+\.md$/.md/' | sort -u); do
  fichiers=$(ls .claude/reviews | grep -E "^${s%.md}(-[0-9]+)?\.md$")
  f=$(printf '%s\n' "$fichiers" | wc -l)
  p=$(printf '%s\n' "$fichiers" | sed 's|^|.claude/reviews/|' | xargs grep -h '^# Passe' 2>/dev/null | wc -l)
  echo "$(( f > p ? f : p )) $s"
done | sort -rn | head
git log --since="$DEPUIS" --name-only --format= -- .claude CLAUDE.md | sort | uniq -c | sort -rn   # ce qu'on retouche sans cesse
# rendement par relecteur : ses mentions sous une section « Rejeté » contre celles sous « Confirmé / Corrigé » — une heuristique, à ± 10 points, mais l'ordre tient
python3 - <<'EOF'
import re,glob,collections
rev=['code-reviewer','comment-analyzer','code-simplifier','silent-failure-hunter','pr-test-analyzer','type-design-analyzer','layered-rails-reviewer']
c=collections.defaultdict(collections.Counter); sec=None
for f in glob.glob('.claude/reviews/*.md'):
    for line in open(f):
        m=re.match(r'^##+ (.*)',line)
        if m: t=m.group(1).lower(); sec='rej' if 'rejet' in t else ('conf' if re.search('corrig|confirm|bloquant',t) else None); continue
        for r in rev:
            if r in line and sec: c[r][sec]+=1
for r in rev: n=sum(c[r].values()); print(f"{r:24} confirmés {c[r]['conf']:3}  rejetés {c[r]['rej']:3}  {100*c[r]['rej']//max(n,1):3} % rejet")
EOF
```

## Les jetons par poste

Le skill [`mesurer-les-jetons`](../mesurer-les-jetons/SKILL.md) rend le coût d'un arbre d'agents et de la fenêtre. Pour l'audit, sa commande `neufs` s'applique à tous les transcripts de sous-agents de la fenêtre, groupés par `agentType` de leur `.meta.json` : ouvriers, relecteurs (`pr-review-toolkit:*` et `layered-rails:*`), spécification (`spec-nerd`, `tdd-nerd`, `contradicteur`), et les sessions dont une invite invoque `/harness-engineer`. Toute mesure est **dédoublonnée par `message.id`**, sinon elle compte chaque tour autant de fois qu'il est relu.

## M1 à M7 — l'impact d'une découpe

Les sept mesures du plan du 2026-09-14, à rejouer aux dates que les tâches `impact-*` de `.claude/local_tasks/` portent. Toutes partent de `P=~/.claude/projects/<slug>` et d'une fenêtre `DEPUIS`.

```sh
# M1 — jetons du premier tour de chaque sous-agent, médiane par agentType ; et descriptions chargées à chaque tour (forme.py, dernière ligne)
python3 - "$P" "$DEPUIS" <<'EOF'
import json,glob,os,sys,statistics,collections,datetime
P,D=sys.argv[1],sys.argv[2]; first=collections.defaultdict(list)
for meta in glob.glob(f'{P}/*/subagents/*.meta.json'):
    t=meta[:-10]+'.jsonl'
    if not os.path.exists(t) or datetime.datetime.fromtimestamp(os.path.getmtime(t)).strftime('%F')<D: continue
    at=json.load(open(meta)).get('agentType','?')
    for line in open(t):
        try: m=json.loads(line)
        except: continue
        u=(m.get('message') or {}).get('usage') if m.get('type')=='assistant' else None
        if u: first[at].append(u.get('input_tokens',0)+u.get('cache_creation_input_tokens',0)+u.get('cache_read_input_tokens',0)); break
for k,v in sorted(first.items(),key=lambda x:-len(x[1])): print(f'{k:40} {int(statistics.median(v)):>8} n={len(v)}')
EOF

# M2 — les frères lus, par sous-agent : lequel, à quel tour ; puis les frères jamais lus
python3 - "$P" "$DEPUIS" <<'EOF'
import json,glob,os,sys,collections,datetime,re
P,D=sys.argv[1],sys.argv[2]; lus=collections.Counter(); tours=collections.defaultdict(list); n=collections.Counter()
for meta in glob.glob(f'{P}/*/subagents/*.meta.json'):
    t=meta[:-10]+'.jsonl'
    if not os.path.exists(t) or datetime.datetime.fromtimestamp(os.path.getmtime(t)).strftime('%F')<D: continue
    at=json.load(open(meta)).get('agentType','?'); n[at]+=1; tour=0
    for line in open(t):
        try: m=json.loads(line)
        except: continue
        if m.get('type')!='assistant': continue
        tour+=1
        for c in (m.get('message') or {}).get('content') or []:
            if c.get('type')=='tool_use' and c['name'] in ('Read','Bash'):
                s=json.dumps(c['input'])
                for f in re.findall(r'\.claude/(?:agents|skills)/[\w-]+/(?!SKILL\.md)[\w-]+\.md',s):
                    lus[(at,f)]+=1; tours[(at,f)].append(tour)
for (at,f),c in sorted(lus.items()): print(f'{at:20} {f:55} lu {c:3} fois sur {n[at]} runs, tours {sorted(set(tours[(at,f)]))[:6]}')
freres={p for p in glob.glob('.claude/agents/*/*.md')+glob.glob('.claude/skills/*/*.md') if not p.endswith('SKILL.md')}
print('jamais lus :', sorted(freres-{f for _,f in lus}))
EOF

# M3 — appels Skill par rôle, et les gestes faits à la main que les skills partagés remplacent
python3 - "$P" "$DEPUIS" <<'EOF'
import json,glob,os,sys,collections,datetime,re
P,D=sys.argv[1],sys.argv[2]; skill=collections.Counter(); manuel=collections.Counter()
for meta in glob.glob(f'{P}/*/subagents/*.meta.json'):
    t=meta[:-10]+'.jsonl'
    if not os.path.exists(t) or datetime.datetime.fromtimestamp(os.path.getmtime(t)).strftime('%F')<D: continue
    at=json.load(open(meta)).get('agentType','?')
    for line in open(t):
        try: m=json.loads(line)
        except: continue
        for c in ((m.get('message') or {}).get('content') or []) if m.get('type')=='assistant' else []:
            if c.get('type')!='tool_use': continue
            if c['name']=='Skill': skill[(at,c['input'].get('skill'))]+=1
            if c['name']=='Bash':
                cmd=c['input'].get('command','')
                if 'gh pr checks' in cmd: manuel[(at,'gh pr checks')]+=1
                if re.search(r'git tag\b',cmd) and 'reset' in cmd: manuel[(at,'tag+reset')]+=1
                if 'curl' in cmd and 'localhost' in cmd: manuel[(at,'curl localhost')]+=1
print('Skill :',dict(skill)); print('à la main :',dict(manuel))
EOF

# M4 — récidives des règles nées d'un audit ; ajouter une ligne par règle déplacée
python3 - "$P" "$DEPUIS" <<'EOF'
import json,glob,os,sys,collections,datetime,re
P,D=sys.argv[1],sys.argv[2]; V={'PLANIFIÉ','PLAN','ARBITRAGE','LIVRÉ','ÉCRAN','INTERROMPU','BLOQUÉ'}; r=collections.Counter()
for meta in glob.glob(f'{P}/*/subagents/*.meta.json'):
    t=meta[:-10]+'.jsonl'
    if not os.path.exists(t) or datetime.datetime.fromtimestamp(os.path.getmtime(t)).strftime('%F')<D: continue
    if json.load(open(meta)).get('agentType')!='ouvrier': continue
    r['ouvriers']+=1; last=''
    for line in open(t):
        try: m=json.loads(line)
        except: continue
        for c in ((m.get('message') or {}).get('content') or []) if m.get('type')=='assistant' else []:
            if c.get('type')=='text' and c['text'].strip(): last=c['text'].strip().split('\n')[0].strip()
            if c.get('type')=='tool_use' and c['name']=='Bash':
                cmd=c['input'].get('command','')
                if re.search(r'(^|[;&|]\s*)sleep \d',cmd) and not re.search(r'\b(until|while)\b',cmd): r['sleep nu']+=1
                if re.search(r'push.*--force(\s|$)',cmd) and 'lease' not in cmd: r['--force nu']+=1
    r['dernier texte = verdict']+= last in V
print(dict(r))
EOF

# M5 — corrections de l'utilisateur : la commande « ce que l'utilisateur a tapé » de preuves.md, lue à la main ; jamais un compte par mots-clés
# M6 — commits par fichier : forme.py --depuis ; forme du harnais : forme.py
# M7 — passes de revue par PR (ci-dessus), jetons par ticket (mesurer-les-jetons), tickets ouverts (preuves.md § Les PR et Linear)
```

## Contrôles

À rejouer à l'étape 7, tous dans la passe :

```sh
# chemins cités par le harnais et absents du dépôt — ce skill exclu, il cite des chemins morts en exemple ;
# les répertoires git-ignorés exclus aussi, absents d'un clone sans être morts ;
# et ce qui suit un ~/ est un chemin du poste, pas du dépôt : il ne se cherche pas ici
grep -ohE '(^|[^~/])(\.claude|scripts|docs)/[A-Za-z0-9À-ÿ_./-]+' CLAUDE.md .claude/agents/*.md .claude/agents/*/*.md \
  $(ls .claude/skills/*/*.md | grep -v harness-engineer) \
  | sed -E 's/^[^.sd]//; s/[.,)]*$//' | sort -u | while read p; do [ -e "$p" ] || git check-ignore -q "$p" || echo "$p"; done
# la même chose dans les mémoires — sans les chemins de ~/.claude, qui ne sont pas ceux du dépôt
grep -ohE '(^|[^~/])\.claude/[A-Za-z0-9_./-]+' ~/.claude/projects/$(pwd | tr / -)/memory/*.md | sed -E 's/^[^.]//' | sort -u | while read p; do [ -e "$p" ] || echo "$p"; done
# les verdicts que la statusline connaît sont ceux de l'ouvrier
V='PLANIFIÉ|PLAN|ARBITRAGE|LIVRÉ|ÉCRAN|INTERROMPU|BLOQUÉ'   # la même alternance des deux côtés, sinon le contrôle invente un écart
grep -oE "$V" .claude/statusline/subagent.sh | sort -u
grep -oE "^\| \`?($V)\`?" .claude/agents/ouvrier.md | sort -u
# les tableaux de CLAUDE.md nomment les fichiers qui existent
ls .claude/skills .claude/agents
# les liens markdown relatifs résolvent depuis le répertoire de chaque fichier (un frère descendu d'un niveau casse ses ../)
for f in .claude/agents/*.md .claude/agents/*/*.md .claude/skills/*/*.md CLAUDE.md; do d=$(dirname "$f"); grep -oE '\]\(([^)#h][^)]*)\)' "$f" | sed -E 's/^\]\((.*)\)$/\1/; s/#.*//' | while read l; do [ -z "$l" ] || [ "$l" = lien ] || [ -e "$d/$l" ] || echo "$f -> $l"; done; done
# les frères sont liés à un niveau : un frère qui lie un autre frère
grep -lE '\]\([a-z-]+\.md\)' .claude/skills/*/*.md .claude/agents/*/*.md | grep -v SKILL.md
# la forme
python3 .claude/skills/harness-engineer/scripts/forme.py
```

Un gabarit (`AAAA-MM-JJ-`, `OOTS-<n>`) sort naturellement du premier contrôle ; ce qui compte est un vrai chemin qui n'existe plus.
