---
name: refondre-historique
description: Refond l'historique d'une branche en une liste de commits courte et relisible — tag de sauvegarde, reconstruction, vérification que l'arbre est identique et que chaque commit s'analyse, push en --force-with-lease, jamais --force nu. review-loop l'appelle une fois convergé, l'ouvrier après un rebase sur conflit.
---

# refondre-historique

En local, sur une branche qui n'a jamais été fusionnée et n'a donc aucune histoire à préserver. Une branche qui converge après plusieurs passes porte un historique écrit par la boucle et non par le travail : trois versions successives du même commentaire, un correctif qui répare le correctif d'avant, un « rectifie ce que la passe précédente affirmait de faux ». Ces repentirs ont eu leur utilité pendant la boucle ; ils n'en ont aucune pour qui relira la branche.

> [!NOTE]
> **Après une refonte, les SHA ne désignent plus rien.** Ils changent tous, et une signature les change encore. Désigner un commit **par son message** dans une revue, un compte rendu ou une conversation ; un SHA qu'on ne retrouve plus est normal, pas le signe d'une perte.

## 1. Décider la forme

Viser **une liste de commits courte et compréhensible, faite pour une relecture humaine**. Deux conséquences pratiques : les correctifs de revue sont absorbés dans le commit qu'ils corrigent — ce qu'ils ont appris remonte dans son message, qui devient le bon endroit pour dire pourquoi le code a cette forme ; et un correctif indépendant du sujet de la branche, un bug voisin trouvé en chemin, garde son propre commit, parce que c'est exactement ce qu'un relecteur veut pouvoir isoler. Le nombre juste se déduit de là, il ne se fixe pas d'avance.

## 2. Sauvegarder, refondre, vérifier

```sh
git -c tag.gpgsign=false tag -f sauvegarde-<sujet> HEAD   # avant de toucher à quoi que ce soit
BASE=$(git merge-base origin/main HEAD)
# refonte : reset --hard "$BASE", puis reconstruire les commits
git diff sauvegarde-<sujet> HEAD        # DOIT être vide
```

Le `-c tag.gpgsign=false` n'est pas décoratif : `tag.gpgsign` est activé, et un tag signé exige un message, si bien que `git tag -f <nom> HEAD` échoue sur `fatal: no tag message?`. Une sauvegarde est un repère local et jetable, elle n'a rien à signer.

**La vérification qui compte porte sur l'arbre final, pas sur chaque commit** : `git diff` entre la sauvegarde et le nouveau HEAD doit être vide, sans quoi la refonte a perdu ou ajouté quelque chose. Ce skill refond une branche sur sa base ; il ne sert pas à pousser un rebase sur `main`, où ce diff n'est jamais vide — `ouvrier/conflit.md` pousse lui-même. Vérifier en plus que ce qui doit s'analyser s'analyse à *chacun* des commits (`sh -n`, `ruby -c`, selon) — un historique relisible est un historique bissectable, et reconstruire à la main des états intermédiaires est précisément ce qui peut produire un commit qui ne tient pas debout tout seul. Si `rebase` refuse des fichiers pourtant propres, c'est le bac à sable : rejouer avec `git -c core.checkStat=minimal`.

## 3. Pousser, seulement si tout est vérifié

```sh
git push --force-with-lease
```

`--force-with-lease` et jamais `--force` nu : il refuse si quelqu'un a poussé sur la branche entre-temps, ce qui est exactement le cas où il ne faut surtout pas écraser. **Si une seule vérification échoue, ne pas pousser** : rendre la main en disant laquelle, la sauvegarde étant encore en place.

L'arbre étant identique au bit près, la CI d'avant la refonte dit déjà ce que celle d'après dira — mais elle le dit d'un SHA que la PR ne porte plus. Ce n'est pas la même affirmation, et l'écart n'est pas théorique : une suite qui monte une stack Domibus échoue parfois sans que le code y soit pour rien. Le force-push a lancé une nouvelle CI : `Skill(skill: "ci-en-fond")`, et ne rendre la main qu'une fois verte — « livré » se dirait sinon d'un état que personne n'a vu vert.

## 4. Laisser de quoi revenir en arrière, ou solder

```sh
git reset --hard sauvegarde-<sujet>   # revenir à l'historique d'avant
git tag -d sauvegarde-<sujet>         # ou s'en débarrasser
```

Dire à l'appelant que l'historique a été refondu et repoussé, puisque les SHA ont changé sous les pieds de qui suivait la PR, et lui laisser ces deux commandes.
