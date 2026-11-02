---
name: ci-en-fond
description: Met la CI d'une PR sous surveillance en tâche de fond, puis lit son verdict et itère jusqu'au vert. Un check rouge est un correctif ; CodeQL se lit à part ; le même check rouge deux fois, ou une panne d'infra, arrêtent. À invoquer dès qu'une PR vient d'être poussée — review-loop, refondre-historique et l'ouvrier l'appellent.
---

# ci-en-fond

Entrée : l'URL ou le numéro de la PR. La CI est un relecteur de plus, pas un feu rouge à attendre : elle se lance sans qu'on l'attende, et son verdict se lit avant de repousser.

## 1. Mettre sous surveillance, sans attendre

Lancer `gh pr checks <url> --watch` **en tâche de fond** (`Bash(run_in_background: true)`), puis enchaîner sur ce qui reste à faire. Dans les secondes qui suivent un push, `gh pr checks` répond `no checks reported` : les workflows ne sont pas encore enregistrés. Guette-le, ne devine pas un délai — `timeout 120 sh -c 'until ! gh pr checks <n> 2>&1 | grep -q "no checks reported"; do sleep 5; done'` avant le `--watch` (relevé sur 6 ouvriers sur 31 entre le 2026-09-15 et le 2026-09-29, chacun paré par un `sleep` nu de 25 à 50 s). CI et revue portent sur le même diff sans dépendre l'une de l'autre ; les paralléliser économise une CI complète (`e2e.yml` monte une stack Domibus) par passe.

**Chaque push tue la surveillance de fond** : la tête change, `gh` imprime `no checks reported` et sort en 1. Relance-la après chaque push, garde comprise, et ne lis jamais ce 1 comme un check rouge.

Le code de sortie de `gh pr checks` ne dit pas que les checks existent : il vaut 8 tant qu'ils tournent et 1 dès que l'un échoue, si bien qu'une boucle sur lui attend le vert et non leur enregistrement. C'est le message qu'on guette.

**Vaut dès la première passe** : la CI de l'ouverture de la PR tourne souvent encore quand la boucle démarre, et ne doit pas retarder la première revue. Si elle est déjà finie, `--watch` rend la main aussitôt. Un brouillon (`--draft`) déclenche les trois workflows comme une PR ordinaire, tous posés sur `pull_request` sans condition de brouillon : `e2e.yml` tourne donc bel et bien, et c'est le seul endroit où le bout-en-bout est joué.

> [!TIP]
> **PR ouverte, la CI fait foi : lire `gh pr checks`, ne pas rejouer la suite en local par-dessus.** Elle tourne déjà, sur un environnement propre que la machine locale n'imite pas. Rejouer coûte des minutes et masque justement les écarts d'environnement qu'on veut voir.

## 2. Quand il ne reste rien d'autre, attendre en bloquant, sous 180 s

« Sans l'attendre » vaut tant qu'il y a autre chose à faire : quand il n'y a plus rien, on attend le verdict dans son propre tour plutôt que de rendre la main.

```sh
.claude/skills/ci-en-fond/scripts/attendre.sh <n>
#   0 → tout est vert
#   1 → un check a échoué : la sortie dit lequel
# 124 → toujours en cours, ou la tête vient de changer : relance la même commande
```

**Rien d'autre que ce script, et rien devant lui.** Il guette l'enregistrement des checks puis les surveille, sous une borne de 150 s : l'outil `Bash` déplace en tâche de fond toute commande encore active à 180 s, et l'appelant récupère alors son tour sans verdict. C'est ce qui est arrivé deux fois le 2026-11-02 (OOTS-284, OOTS-260) avec un `timeout 240 gh pr checks --watch` : l'attente est partie en fond, l'ouvrier a rendu la main en « attendant la notification », et l'un est resté actif après sa livraison. Il traite aussi `no checks reported` en cours de surveillance — ce que `gh` imprime, code 1, quand un push remplace la tête — comme un « relance », jamais comme un check rouge.

**Une attente guette une condition ; elle ne compte jamais du temps.** Le script, `gh run watch`, ou `until <vérification>; do sleep 2; done` sous `timeout` de moins de 180 s : la commande rend la main quand la chose attendue arrive, ou quand la borne tombe. Pour la sortie d'une tâche de fond, attendre sa notification, ou guetter le fichier de sortie par `until grep -q <motif> <fichier>`.

**Rejoue l'attente plutôt que de l'allonger** : en tranches sous la borne, chacune laisse une trace, on reste pilotable, et un message qui attend est délivré entre deux.

**Aucune surveillance ne survit à ton rapport.** Avant de rendre un verdict à l'appelant — `verte`, `rouge`, `arrêt`, ou le `LIVRÉ` d'un ouvrier —, arrête chaque surveillance de fond encore en cours (`TaskStop` sur son identifiant) : une tâche de fond orpheline garde l'agent actif après sa fin, dans le panneau comme dans les jetons.

## 3. Lire le verdict

Un check rouge est un finding **bloquant** : lire les logs (`gh run view <run-id> --log-failed`), corriger, et regrouper avec les autres correctifs en cours plutôt que d'en faire un cycle séparé. Si l'échec montre que le diff **ne construit pas**, réparer d'abord, puis relire les findings restants sur le code réparé avant de les appliquer. Ne pas interrompre des agents de revue encore en cours : leurs findings valent sur le même diff.

**L'analyse statique ne se lit pas dans le statut du check.** Un CodeQL en échec affiche « fail » sans dire quoi, et ses alertes se récupèrent à part, à chaque passe, même quand le check était vert la fois d'avant — une alerte introduite par un correctif se trouve là et nulle part ailleurs :

```sh
gh api "repos/<dépôt>/code-scanning/alerts?pr=<n>&state=open"
```

Si le **même** check échoue deux fois de suite malgré un correctif, ou si l'échec ne vient visiblement pas du code (flakiness d'infra, runner qui ne peut pas monter la stack Domibus), arrêter d'itérer et le dire à l'appelant : quel check, ce que ses logs montrent, ce qui a été tenté.

## Ce que tu rends

Une ligne : `verte` ; ou `rouge : <check>, <ce que les logs montrent>, <ce qui a été tenté>` ; ou `arrêt : <même check deux fois | infra>, <détail>`. L'appelant décide de la suite — repousser, reboucler, rendre un verdict.
