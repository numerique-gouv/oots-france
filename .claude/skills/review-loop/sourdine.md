# Silence pendant la boucle

Lu en entrant dans la boucle, avant la première passe.

Les agents de l'étape 2 tournent en tâche de fond : chacun qui rentre relance la conversation, qui commente et rend la main — donc un `Stop`, donc un son « tâche terminée » de peon-ping, alors que rien n'attend l'utilisateur. Sept agents, sept sons pour une seule passe. Mettre la session en sourdine :

```sh
~/.claude/hooks/peon-quiet.sh on     # avant la première passe
~/.claude/hooks/peon-quiet.sh off    # avant de rendre la main, quelle qu'en soit la raison
```

Le `off` n'est pas optionnel et ne vaut pas que pour la fin normale (étape 6, branche « Non ») : **tout** endroit où la boucle rend la main à l'utilisateur le réclame d'abord — finding ambigu (étape 4), CI rouge deux fois ou échec d'infra (étape 4bis), arbitrage d'oscillation (garde-fou, point 3), règle des 5 passes. Sinon la question part sans son, ce qui est exactement le contraire du but : on coupe le bruit pour que le silence redevienne informatif.

La sourdine ne porte que sur `Stop` et les rappels d'inactivité, et seulement sur cette session. Les demandes de permission et les questions continuent de sonner pendant la boucle, et les autres sessions ne sont pas touchées. Un marqueur oublié (boucle interrompue, session tuée) expire tout seul au bout d'une heure sans activité. Le mécanisme est dans `~/.claude/hooks/peon-quiet.sh`, qui sert de portier devant `peon.sh` — son en-tête explique le reste.
