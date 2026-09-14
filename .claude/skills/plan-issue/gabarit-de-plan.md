# Le gabarit du plan

Lu en phase 4, quand le fichier se complète. Une ligne « Décision du AAAA-MM-JJ : … » en tête, au-dessus du Contexte, est la réponse rendue à un `PLAN` par qui l'a reçu : elle prime sur le corps qu'elle corrige.

Le fichier se complète (il existe depuis la phase 1). C'est un **document de décision**, pas un tutoriel : assez court pour se parcourir, assez précis pour s'exécuter. **Seule l'approche retenue y figure** — ce qu'on a écarté tient en une ligne dans « ce que j'ai tranché seul », pas en section.

| Rubrique | Ce qu'elle porte |
| --- | --- |
| **Contexte** | en tête, avant tout le reste : le besoin ou le défaut traité, ce qui l'a déclenché, ce qu'on veut obtenir |
| **Ce que ça change** | deux phrases, lisibles sans ouvrir le ticket |
| **Ce que les TDD imposent** | chapitre par chapitre, **liés**, avec les règles `R-EDM-*` citées par leur identifiant. Un plan qui ne cite aucun chapitre est un plan inachevé |
| **Le désaccord avec le ticket** | s'il y en a : ce que le ticket dit, ce que le chapitre dit, ce qu'on fait |
| **Ce que ça ne fait pas** | le périmètre coupé, et pourquoi |
| **Les fichiers critiques** | ceux qu'on modifie, nommés, avec **la couche de chacun**. Un pattern qui se répète se décrit **une fois**, avec deux ou trois chemins représentatifs — n'énumère ni tous les fichiers ni des numéros de ligne |
| **Ce qu'on réutilise** | les objets, méthodes et fabriques existants réemployés, **avec leur chemin**. Ce qu'on crée faute d'avoir trouvé, dit comme tel |
| **Ce que les specs prouveront** | les cas, pas les fichiers. Toute nouveauté vient avec ses specs |
| **Comment on vérifie** | la commande qui prouve que ça marche : `make test` toujours ; `make schematron` si `app/templates/` ou `app/builders/` bougent ; `make i18n` si `fr.yml` bouge ; le e2e, qui tourne en CI (`e2e.yml`), pas en local |
| **Ce que j'ai tranché seul** | une ligne par décision, avec sa raison |
| **Questions ouvertes** | ce qui reste à trancher, avec l'option recommandée et pourquoi. Aucune question : pas de rubrique |

Et ces cinq-là, qu'un plan oublie régulièrement et qui reviennent en revue :

- **`config/locales/fr.yml`** si une phrase atteint un écran : les clés prévues, sous la forme « chemin de ce qui dit la chaîne ». Aucune phrase française ne reste dans `app/`.
- **`db/seeds.rb`** si une colonne est ajoutée, renommée, ou si ce qu'un écrivain enregistre change : les seeds font partie du changement, et ne remplissent un champ que là où le code de production le remplit.
- **Les variables d'environnement** : `.env*.template` avec un commentaire français **et** `scripts/ci/prepare_environment.sh`, dont le contrôle de contrat échoue sinon.
- **La documentation propriétaire** du sujet — un seul document, les autres lient. Et `docs/reste_à_faire.md` si le plan pose un bouchon, qui vient avec son commentaire nommant l'issue Linear.
- **La migration**, s'il y a schéma : **en un temps**, sans compatibilité ascendante ni backfill, rien n'étant en service. Le dire plutôt que le laisser deviner.

Si le plan s'écarte de ce que la description du ticket annonçait, **resynchronise-la** (`save_issue`, par `patch`) : le ticket est la trace durable, le plan le détail.
