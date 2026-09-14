---
name: ci-en-fond
description: Met la CI d'une PR sous surveillance en tâche de fond, puis lit son verdict et itère jusqu'au vert. Un check rouge est un correctif ; CodeQL se lit à part ; le même check rouge deux fois, ou une panne d'infra, arrêtent. À invoquer dès qu'une PR vient d'être poussée — review-loop et l'ouvrier l'appellent.
---

# ci-en-fond

Entrée : l'URL ou le numéro de la PR. La CI est un relecteur de plus, pas un feu rouge à attendre : elle se lance sans qu'on l'attende, et son verdict se lit avant de repousser.

## 1. Mettre sous surveillance, sans attendre

Lancer `gh pr checks <url> --watch` **en tâche de fond** (`Bash(run_in_background: true)`), puis enchaîner sur ce qui reste à faire. CI et revue portent sur le même diff sans dépendre l'une de l'autre ; les paralléliser économise une CI complète (`e2e.yml` monte une stack Domibus) par passe.

**Vaut dès la première passe** : la CI de l'ouverture de la PR tourne souvent encore quand la boucle démarre, et ne doit pas retarder la première revue. Si elle est déjà finie, `--watch` rend la main aussitôt. Un brouillon (`--draft`) déclenche les trois workflows comme une PR ordinaire, tous posés sur `pull_request` sans condition de brouillon : `e2e.yml` tourne donc bel et bien, et c'est le seul endroit où le bout-en-bout est joué.

> [!TIP]
> **PR ouverte, la CI fait foi : lire `gh pr checks`, ne pas rejouer la suite en local par-dessus.** Elle tourne déjà, sur un environnement propre que la machine locale n'imite pas. Rejouer coûte des minutes et masque justement les écarts d'environnement qu'on veut voir.

## 2. Quand il ne reste rien d'autre, attendre en bloquant

« Sans l'attendre » vaut tant qu'il y a autre chose à faire : quand il n'y a plus rien, on attend le verdict dans son propre tour plutôt que de rendre la main.

```sh
timeout 240 gh pr checks <n> --watch --interval 30
#   0 → tout est vert          1 → un check a échoué
# 124 → toujours en cours, relance la même commande
```

**Une attente guette une condition ; elle ne compte jamais du temps.** `gh pr checks --watch`, `gh run watch`, ou `until <vérification>; do sleep 2; done` sous `timeout` : la commande rend la main quand la chose attendue arrive, ou quand la borne tombe. Pour la sortie d'une tâche de fond, attendre sa notification, ou guetter le fichier de sortie par `until grep -q <motif> <fichier>`.

**Borne chaque attente, et rejoue-la** : l'outil `Bash` coupe à 600 s, et une commande tuée par ce plafond ne dit pas si les checks avaient fini — elle ne dit rien du tout. En tranches de quelques minutes, chacune laisse une trace, on reste pilotable, et un message qui attend est délivré entre deux.

## 3. Lire le verdict

Un check rouge est un finding **bloquant** : lire les logs (`gh run view <run-id> --log-failed`), corriger, et regrouper avec les autres correctifs en cours plutôt que d'en faire un cycle séparé. Si l'échec montre que le diff **ne construit pas**, réparer d'abord, puis relire les findings restants sur le code réparé avant de les appliquer. Ne pas interrompre des agents de revue encore en cours : leurs findings valent sur le même diff.

**L'analyse statique ne se lit pas dans le statut du check.** Un CodeQL en échec affiche « fail » sans dire quoi, et ses alertes se récupèrent à part, à chaque passe, même quand le check était vert la fois d'avant — une alerte introduite par un correctif se trouve là et nulle part ailleurs :

```sh
gh api "repos/<dépôt>/code-scanning/alerts?pr=<n>&state=open"
```

Si le **même** check échoue deux fois de suite malgré un correctif, ou si l'échec ne vient visiblement pas du code (flakiness d'infra, runner qui ne peut pas monter la stack Domibus), arrêter d'itérer et le dire à l'appelant : quel check, ce que ses logs montrent, ce qui a été tenté.

## Ce que tu rends

Une ligne : `verte` ; ou `rouge : <check>, <ce que les logs montrent>, <ce qui a été tenté>` ; ou `arrêt : <même check deux fois | infra>, <détail>`. L'appelant décide de la suite — repousser, reboucler, rendre un verdict.
