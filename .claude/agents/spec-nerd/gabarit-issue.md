# Le gabarit d'une issue

Lu à la rédaction du jet (CRÉER, étape 3).

**Une seule nature : la `US`**, un sujet qu'on relit comme un tout, pour un acteur nommé — et **pas de hiérarchie** : ni parent, ni sous-issue. Un sujet trop gros se découpe en plusieurs `US` de plain-pied, reliées par `blockedBy` quand l'ordre compte. Il n'y a pas de ticket technique : les questions techniques que soulève une `US` sont levées par l'ouvrier en planifiant, et réglées en implémentant. L'outillage, la dette et l'exploitation s'écrivent aussi en `US`, avec l'exploitant ou le développeur pour acteur — ce qu'ils veulent voir vrai, pas ce qu'il faut coder.

Titre en français, verbe à l'infinitif : `US - Rejeter une requête dont l'identifiant a déjà été traité`.

### L'en-tête

```md
|  |  |
| -- | -- |
| **Chapitre** | [4.6 — Règles métier](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) |
| **Acteur** | Data Service |
| **Priorité** | MUST |
| **Description** | En tant que **Data Service**, je dois **rejeter une requête dont l'identifiant a déjà été traité**, afin que **le correspondant ne puisse pas rejouer un échange**. |
```

- **Chapitre** : celui qui fonde le ticket, lié. Sans chapitre — exploitation, outillage, dette — écris `**Aucun** — <motif>` : la règle de `CLAUDE.md`, « *a feature is justified by a chapter, or it does not ship* », vaut pour un ticket, et ce qui y échappe le dit.
- **Acteur** : un coin du modèle à quatre coins — *Evidence Requester*, *Evidence Provider*, *Data Service*, *Preview Space* — ou l'exploitant, pour la console. Cette application parle à des machines : nommer le coin qui agit rend l'énoncé vrai, là où un usager humain inventé le rendrait faux.
- **Priorité** : la force normative de ce qu'on implémente — `MUST`, `SHOULD`, `COULD` —, pas la priorité Linear, qui se calcule par `priorite.md`.
- **Description** : *En tant que / je dois / afin que*, trois segments en gras, une phrase.

### Le corps

```md
## Contexte

<Deux à cinq lignes : d'où vient le besoin, ce qui existe déjà, ce qui a été décidé et où. Pas d'exposé du chapitre — il est lié.>

Spécifié contre `main` à `9ca67a3f`, le 2026-09-15.

## Règles de gestion

| RG | Description | Source |
| -- | -- | -- |
| RG1 | Une requête dont l'identifiant a déjà été reçu est rejetée par une exception `EDM:ERR:0006`. | [`R-EDM-REQ-S009`](lien) |

## Critères d'acceptance

| CA | Description | RG |
| -- | -- | -- |
| CA1 | **Étant donné** une requête déjà traitée, **lorsque** la même arrive de nouveau, **alors** la réponse est une `ExceptionResponse` portant `EDM:ERR:0006` et aucun justificatif n'est produit. | RG1 |

## Hors périmètre

- Ne traite pas la réponse en erreur côté requêteur, qui est OOTS-nn.

## Vérification

`make test`, `make schematron`. Un scénario de bout en bout : …
```

Ce que chaque section doit à son lecteur :

- **Le contexte finit par la base de spécification** — le commit de `main` contre lequel le ticket a été écrit, et la date. Un ticket décrit un dépôt qui bouge sous lui : deux fusions suffisent à rendre faux un nom de méthode, un libellé d'écran ou le mot qu'un scénario employait, et sans cette ligne personne ne sait ce qui a été vérifié ni quand. Elle se remet à jour à chaque passe qui rebase le ticket.
- **Chaque règle de gestion cite sa source, et la source est un lien** : une règle nommée, un chapitre, un `.sch`, un XSD, un article de règlement, une RFC. Deux exceptions — une décision locale déjà rendue, citée avec le ticket ou le commentaire qui la rend ; une contrainte du dépôt, citée avec le fichier. Une RG sans source n'est pas fausse, elle est invérifiable, et cela suffit à laisser le ticket en `À compléter`. Une RG dit ce que le texte dit : pas un *may* durci en « doit », pas un acteur prêté à un passage qui n'en nomme aucun.
- **Chaque critère se lit comme un test qu'on saurait écrire** : un sujet, un déclencheur, un résultat observable, en *Étant donné / Lorsque / Alors* — la forme des scénarios Cucumber du dépôt. « Les erreurs sont gérées » est une intention ; « la réponse porte `EDM:ERR:0006` et aucun justificatif n'est produit » est un critère. Chaque CA renvoie à sa RG ; une RG sans CA est une règle qu'on ne prouvera pas.
- **Le hors-périmètre dit ce que le ticket ne fait pas**, dès qu'un lecteur pourrait raisonnablement en faire plus : un chapitre dont on n'implémente qu'une partie, un format à champs optionnels, une règle qui a un pendant symétrique. C'est ce qui empêche les deux fautes que `CLAUDE.md` nomme — inventer, reconduire — au moment où elles se commettent : chez quelqu'un qui a lu un ticket muet et rempli le silence. Une ligne par exclusion, avec le ticket qui la porte s'il existe.
- **La vérification tient lieu de définition de fini** : des commandes qu'on joue vraiment (`make test`, `make schematron`, `make e2e`), et ce qu'on doit y voir.

Ce qui **n'y est pas** : de maquette (il n'y en a pas), d'estimation (l'équipe n'en fait pas), de section « solution » ou « pistes techniques », de DOR/DOD, et aucune instruction adressée à un agent — un ticket décrit un travail, il ne donne pas d'ordre à qui le lit. Une question encore ouverte, si l'utilisateur l'a différée, se dit **telle quelle** dans une section `## Questions ouvertes`, jamais masquée derrière une formulation affirmative — et le ticket reste en `À compléter`, ce qui est exactement ce qu'il faut.
