# Versions des TDD et passage de version

> Ce document explique comment les spécifications OOTS sont versionnées,
> comment une version est annoncée dans les échanges, comment les États
> membres passent d'une version majeure à la suivante, et quelle version ce
> dépôt doit viser. Pour le reste du contexte OOTS, voir
> [oots_context.md](oots_context.md).

## Le versionnement des TDD

Les [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview)
sont publiés par la Commission européenne en versions numérotées
`majeure.mineure.correctif`, chacune archivée avec son changelog dans
l'[historique des versions](https://ec.europa.eu/digital-building-blocks/sites/display/TDD/OOTS+Technical+Design+Documents+Releases).
Chaque chapitre porte en outre son propre numéro de version — au sein d'une
même release, les chapitres n'évoluent pas tous au même rythme.

Une version majeure est **adoptée par consensus** par le *Gateway Coordination
Group* du Portail Numérique Unique, l'instance où siègent les États membres.
Ce n'est donc pas une décision unilatérale de la Commission, ce qui explique
la prudence des calendriers de migration : ils se négocient.

Deux versions majeures existent à ce jour :

| Version | Adoption | Identifiant EDM |
| --- | --- | --- |
| v1.x (jusqu'à 1.2.4) | décembre 2023, puis mineures et correctifs | `oots-edm:v1.0` … `oots-edm:v1.2` |
| v2.0 | 19 février 2026 | `oots-edm:v2.0` |

## Comment une version est annoncée dans les échanges

C'est le mécanisme central à comprendre : rien n'oblige tout le réseau à
parler la même version au même moment, parce que la version fait partie des
métadonnées publiées et négociées avant l'échange.

Deux endroits se répondent :

- **Dans le DSD** (*Data Service Directory*), chaque *Access Service* déclare
  un ou plusieurs éléments `sdg:ConformsTo` — « la ou les versions du profil
  eDelivery et du modèle de données d'échange utilisées par l'*access
  service* » — par exemple `oots-edm:v1.0` et `oots-edm:v1.2` côte à côte,
  comme le montre la
  [spécification de l'interface de requête du DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/920061713/3.1.3+Query+Interface+Specification+of+the+DSD+v1.2.3+September+2025).
  Le pluriel est le point important : un fournisseur peut annoncer qu'il
  comprend plusieurs versions.
- **Dans le message**, le slot `SpecificationIdentifier` porte la version
  effectivement employée (`oots-edm:v1.0` dans ce dépôt, voir
  `src/ebms/requeteJustificatif.js`). Les TDD imposent qu'il **corresponde au
  `ConformsTo` de l'*Access Service* retenu** par l'*Evidence Requester* lors
  de sa requête au DSD.

Autrement dit, le requêtant interroge le DSD, y lit les versions que sa cible
sait traiter, en choisit une qu'il sait produire, puis l'annonce dans le
message. La cohabitation de plusieurs versions sur le réseau est donc prévue
par la spécification elle-même, et non bricolée après coup.

## Le passage de v1.x à v2.0

### Ce que la Commission a effectivement décidé

La [v2.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/952471419/Commission+releases+version+2.0+of+the+OOTS+Technical+Design+Documents)
n'est **pas rétrocompatible** avec les v1.x. Ses objectifs annoncés : couvrir
l'intégralité du règlement d'exécution, adopter les justificatifs structurés,
adopter les fonctionnalités eDelivery avancées — dont le
[SMP](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467117984/SMP+specifications),
qui apporte une découverte dynamique des capacités des participants —,
renforcer le profil de sécurité, supprimer les fonctionnalités dépréciées,
ouvrir OOTS aux démarches de qualifications professionnelles, de permis de
conduire et de location de courte durée, et préparer les synergies avec
eIDAS 2 et le *wallet* (EUDI).

Mais la bascule n'a pas été sèche : **le même jour, la Commission a publié le
correctif 1.2.4**, dont l'objet explicite est de « permettre la poursuite de
l'usage de la version mineure 1.2 » et qui rétroporte une partie des mises à
jour de listes de codes de la 2.0. La ligne 1.2 reste donc vivante et
maintenue, en parallèle de la 2.0.

### Ce qui n'a pas été publié

> [!IMPORTANT]
> Aucune date de fin de support de la v1.x, aucune échéance de migration et
> aucune règle de coexistence n'ont été publiées avec la v2.0. Toute
> planification qui suppose une date de bascule imposée s'appuierait sur une
> information qui n'existe pas — vérifier auprès du *Gateway Coordination
> Group* avant de s'engager sur un calendrier.

### Comment les États membres s'en accommodent en pratique

Les échanges OOTS étant bilatéraux, la contrainte n'est pas « chaque pays
maintient deux piles » mais « chaque pays doit parler la version de ses
correspondants ». Combiné au `ConformsTo` du DSD, cela donne une migration
par vagues plutôt qu'un basculement coordonné :

- les pays qui migrent tôt publient deux *Access Services* — ou un seul
  annonçant les deux versions — et acceptent les deux formats ;
- les pays restés en 1.2 continuent d'échanger normalement, avec une
  spécification toujours maintenue ;
- le réseau converge à mesure que la 1.x perd ses derniers utilisateurs, et
  la fin de vie se décidera alors dans les instances, sur constat.

C'est le schéma habituel des réseaux « quatre coins » à découverte
centralisée : la migration est portée par les métadonnées, pas par un
calendrier commun.

## Quelle version viser pour ce dépôt

Le code cible `oots-edm:v1.0`, c'est-à-dire la toute première version majeure
— pas le sommet de la ligne 1.x, qui est 1.2.4. Deux écarts se cumulent donc :
le retard *au sein* de la v1.x, et la marche vers la v2.0. D'où la question,
au moment de la reprise : rattraper la 1.2, ou aller directement à la 2.0 ?

**La recommandation est de viser directement la v2.0.** Trois raisons.

D'abord, l'argument habituel en faveur de la 1.2 — « c'est la version qui
interopère aujourd'hui » — ne s'applique pas ici. Ce dépôt n'échange avec
personne : les [manques identifiés](oots_context.md#ce-que-ne-fait-pas-encore-ce-dépôt)
(Common Services réels, Preview Space, fournisseurs de données, réconciliation
d'identité) empêchent de toute façon un échange réel de bout en bout. Une
conformité 1.2 achèterait donc une interopérabilité inutilisable en l'état.

Ensuite, la 1.2 ne couvre pas entièrement le
[règlement d'exécution (UE) 2022/1463](https://eur-lex.europa.eu/eli/reg_impl/2022/1463/oj) :
la 2.0 s'annonce comme apportant « une couverture complète de toutes les
exigences du règlement d'exécution », ce qui dit en creux que la ligne 1.x ne
l'atteint pas. Bâtir sur 1.2 un système qui devra être homologué et
transporter des données sensibles part d'une base connue comme incomplète.

Enfin, la 2.0 est la version qui prépare eIDAS 2 et les synergies avec le
*wallet* (EUDI) — c'est-à-dire l'axe vers lequel les budgets ont été
réorientés lors de la mise en hibernation du projet. La viser réaligne le
dépôt avec le cadre qui le finance.

S'y ajoute le coût : `oots-edm:v1.0` → `1.2` représente deux versions mineures
de mappings de syntaxe et de listes de codes, dont l'essentiel serait ensuite
jeté, la 2.0 étant une réécriture des messages plutôt qu'une mise à jour.

### Le préalable à lever

> [!IMPORTANT]
> Vérifier auprès du Service Desk que le validateur OOTS et la plateforme ITB
> ([Testing Services](https://ec.europa.eu/digital-building-blocks/sites/spaces/OOTS/pages/787775546/Testing+Services))
> acceptent la v2.0, et demander la version cible du prochain Projectathon :
> le dernier événement pair-à-pair documenté ici est le Projectathon 6 de juin
> 2025, donc sous v1.x. Développer contre une spécification qu'on ne peut pas
> valider est le seul risque sérieux de ce choix.

Ce risque reste limité : la validation autonome (schémas XML, règles
Schematron, listes de codes) ne dépend pas des autres États membres. Seul le
test pair-à-pair en dépend, et il suppose de toute façon d'avoir d'abord
comblé les manques fonctionnels.

### Par où commencer

Ne pas traiter cela comme une migration. La première tâche — confronter
`src/ebms/` aux mappings de syntaxe courants — est nécessaire quelle que soit
la cible : la mener **contre la v2.0** donne la taille réelle de l'écart avant
tout engagement irréversible.

Les changements qui touchent directement ce dépôt commencent par l'identifiant
`oots-edm:v2.0` et par de nouveaux slots dans les messages (prévisualisation,
classification du fournisseur, alignement de l'identité sur les données PID du
*wallet*), décrits dans le
[mapping de syntaxe des requêtes v2.0.0](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/952470359/4.5.1+-+Evidence+Request+Syntax+Mapping+v2.0.0+March+2026)
et dans le changelog de la release. L'inventaire exhaustif reste à faire.
