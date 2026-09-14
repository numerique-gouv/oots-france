# Le gabarit de l'audit

Lu à l'étape 5. L'audit va dans `.claude/audits/AAAA-MM-JJ-harnais.md` du checkout principal — `AAAA-MM-JJ-harnais-<sujet>.md` pour une passe sur une demande. Un constat appliqué sans sa ligne `Impact attendu` n'est pas fini.

```md
# Harnais — passe du AAAA-MM-JJ

Fenêtre : du … au …, <n> sessions, <n> sous-agents, <n> PR, <n> tickets touchés.
Précédent : <lien vers l'audit d'avant, ou « premier »>.

## Impact des passes précédentes
| Tâche | Mesure | Base | Résultat | Tenu / non tenu / non mesurable |
| --- | --- | --- | --- | --- |

## Mesures
| | Cette fenêtre | Précédente |
| --- | --- | --- |
| corrections de l'utilisateur dans les transcripts | | |
| questions posées dont la réponse était écrite | | |
| passes de revue par PR (médiane, max) | | |
| jetons neufs par ticket (médiane) | | |
| fichiers du harnais retouchés | | |
| forme du harnais (`forme.py`) : fichiers au-dessus d'un seuil, descriptions chargées, doublons | | |
| tickets ouverts en fin de fenêtre (Todo + Backlog + À compléter + In Progress) | | |
| reliquats devenus tickets / tickets fermés | | |
| jetons neufs par poste : ouvriers / relecteurs / spécification / harnais | | |
| constats rejetés par relecteur (les trois pires) | | |

## Constats
### <n>. <une ligne : le défaut>
**Pilier** : contexte | contraintes | entropie
**Preuve** : <session, agent, horodatage, ou fichier:ligne, ou PR, ou la mesure — relevé dans cette passe>
**Remède** : <écrire | déplacer | raccourcir | mécaniser | corriger | fusionner | retirer | rapatrier | mesurer> — <où, en une phrase>
**Impact attendu** : <mesure> — base <valeur, date> — attendu <sens ou seuil> — remesure le <date> — si non : <geste local>
**Appliqué** : oui, commit « … » | proposé, attend une réponse

## Mémoires rapatriées
| Mémoire | Vers | À supprimer après merge |

## Ce que je n'ai pas pu vérifier
<les sources hors d'atteinte, les transcripts trop gros pour être lus en entier, et pourquoi>
```

Le compte rendu dans le fil : le lien de la PR, le nombre de constats appliqués et proposés, les deux ou trois qui changent le plus, une ligne d'impact attendu par constat appliqué, la liste des mémoires à supprimer après merge. Pas le détail — il est dans l'audit.
