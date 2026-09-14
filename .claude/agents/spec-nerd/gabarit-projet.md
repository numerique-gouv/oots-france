# Le gabarit d'un projet

Lu au service PROJET, étape 3.

Le nom est `[OOTS-France] - <Sujet>`, le sujet en quelques mots, sans verbe : `[OOTS-France] - La prévisualisation`. Le préfixe est ce qui le distingue des projets des autres équipes dans les vues de l'espace de travail.

Le **résumé** (`summary`) est une phrase, celle qui s'affiche dans les listes : ce que le chantier livre, pour qui. Pas de point d'entrée dans la description, elle vit ailleurs.

La **description** :

```md
## Contexte

<Trois à six lignes : ce que le règlement ou les TDD attendent sur ce sujet, ce que le dépôt fait aujourd'hui, ce qui manque. C'est ce qu'un nouveau lecteur lit pour comprendre pourquoi le chantier existe.>

## Objectifs

- **<Ce qui sera vrai à la fin>** : une ligne qui le précise.
- …

## Ce que le projet couvre

- <Un point par sujet, au grain d'une US future ou existante. C'est la liste contre laquelle une issue trouve son projet.>

## Ce que le projet ne couvre pas

- <Ce qu'un lecteur rangerait ici par erreur, et le projet qui le porte.>

## Chapitres

- [4.9 — Espace de prévisualisation](lien)

## Dépendances

<Les projets ou décisions dont celui-ci attend quelque chose, et ce qu'il attend.>
```

Ce que chaque section doit à son lecteur :

- **Le contexte dit le pourquoi, pas le comment.** Il nomme le droit de l'usager, l'obligation du fournisseur, le cas d'usage — ce qu'un lecteur qui ne connaît pas OOTS comprend. Les chapitres sont liés, pas recopiés.
- **Les objectifs se lisent comme des résultats**, un par ligne, le résultat en gras puis sa précision — jamais une liste de tâches.
- **La frontière est ce qu'on relira.** « Ce que le projet couvre » et « ce qu'il ne couvre pas » sont les deux sections qui servent après la création : c'est là qu'une issue trouve son projet, et là qu'un doublon se voit. La seconde nomme le projet voisin qui porte chaque exclusion.
- **Les chapitres sont liés**, un par ligne, avec le passage concerné quand le chapitre est large.
- **Un avertissement** (`> [!WARNING]`) porte ce qui bloque en dehors du chantier — un préalable non rendu, un droit que la France ne peut pas honorer tant qu'il n'est pas fait.

Ce qui **n'y est pas** : ni jalons, ni dates, ni responsable, ni priorité de projet — l'équipe n'ordonne que par la priorité des issues. Ni la liste des issues, que Linear affiche déjà sous le projet et qui divergerait de la description au premier ticket créé.
