---
name: adresse-ecran
description: Monte la pile web d'un worktree sur l'état final et rend l'adresse de chaque page où le travail se constate — port lu dans .env, route complète, seeds, réponse vérifiée par curl, trois mots sur ce qu'on y voit. À invoquer dès qu'une branche touche à ce qui se regarde dans un navigateur ; ship-plan et l'ouvrier l'appellent.
---

# adresse-ecran

Tout ce qui se livre et qui se regarde a une adresse, et l'utilisateur n'a aucun moyen de la reconstituer : `scripts/worktree.sh` décale les ports du worktree, donc ce n'est pas 3000, et rien ne dit lequel c'est sans lire son `.env`. Une revue lit du code ; elle ne dit pas si l'écran est utilisable, et c'est la seule chose que l'utilisateur puisse juger et pas nous. **Rends l'adresse, jamais une image à la place** : une image ne montre que ce que **tu** as vu, sous l'angle que tu as choisi ; l'adresse laisse cliquer, filtrer, redimensionner et changer les mots — ce qui est exactement ce qu'on demande à qui reprend l'écran.

## 1. Monter la pile sur l'état final, et la laisser tourner

```sh
docker compose up -d --no-deps web postgres
docker compose exec -T web bundle exec rails db:prepare   # migrations de la branche
docker compose exec -T web bundle exec rails db:seed      # compte et jeu de démonstration
```

Ne pas éteindre `web` en fin de course : le laisser debout coûte un conteneur, l'éteindre coûte un aller-retour. Éteindre en revanche ce qui est lourd et sans rapport — Domibus et MySQL — sauf si la branche les concerne : la VM a 8 Gio et d'autres agents y travaillent.

## 2. Lire le port, jamais le supposer

```sh
grep '^PORT_OOTS_FRANCE=' .env
```

Chaque worktree décale ses ports, donc `3000` est presque toujours faux — c'est celui du checkout principal, où l'on ne lance rien.

## 3. Une URL par page où le travail se constate, avec la route

**Autant d'URL que de pages où le travail se constate**, et pas une de plus : la liste et la fiche, l'état vide et l'état peuplé, la page qu'un paramètre place dans le cas qu'on vient d'ajouter. Fabrique le lien qui mène **directement** à ce qu'il faut regarder — `http://localhost:3002/admin/journal`, pas `http://localhost:3002` ; un écran qu'on n'atteint qu'en trois clics et un filtre à régler soi-même n'est pas vérifié, il est cherché — et accompagne chacun de trois mots disant ce qu'on y voit, sans quoi la liste ne dit pas pourquoi elle a plusieurs lignes :

```
http://localhost:3002/admin/journal?event_type=answer_not_sent
  → le nouveau type, isolé par le filtre
http://localhost:3002/admin/journal/events/19
  → la fiche, avec le corps RegRep qu'elle est seule à conserver
```

Ce qui rend ces URL regardables, ce sont les **seeds** : une page qui n'a rien à montrer sans données est un `db/seeds.rb` à étendre — `CLAUDE.md` le demande déjà comme partie du changement — jamais une URL à omettre. Donner du même coup ce qu'il faut pour entrer (le compte du seed), et **sur quoi la pile est branchée** quand ça change ce qui s'affiche : annuaires réels ou doublures du bout-en-bout, passerelle allumée ou non. Une capture d'écran d'un doublage lue comme une réponse de la Commission, c'est une revue faussée.

## 4. Vérifier que chacune répond avant de la donner

```sh
curl -so /dev/null -w '%{http_code}\n' <url>
```

Un 404 sur une fiche dont l'`id` n'existe pas se voit là, pas chez l'utilisateur, à qui une adresse morte coûte le temps de comprendre que la panne n'est pas de son côté. Celle que tu ne peux pas faire répondre, dis pourquoi et donne la commande qui la ramène, plutôt que de la passer sous silence.

## Ce que tu rends

La liste des URL, une par ligne, chacune avec ses trois mots et vérifiée joignable ; le compte du seed ; sur quoi la pile est branchée. L'appelant la met aux trois endroits qui la portent : le message qui annonce l'écran, le corps de la PR, et la ligne `Écran` de son verdict.
