# Testing Services — la plateforme de test de la Commission

> Les [Testing Services](https://ec.europa.eu/digital-building-blocks/wikis/spaces/SDGOO/pages/550699923/Testing+Services+-+SDG+OOTS) sont l'outillage que la Commission met à disposition des équipes nationales pour éprouver leur implémentation d'OOTS : un validateur de messages, des annuaires centraux simulés, une passerelle AS4 d'en face, un espace de prévisualisation et une plateforme qui orchestre des cas de test. Ils ne font pas partie des [TDD](carte_des_tdd.md) et n'ajoutent aucune exigence : ils vérifient celles qui existent. La page du wiki demande un compte ; ce document en résume ce qui sert ici, la version courante étant **2026_Q2**, alignée sur les TDD v2.0.1 et v2.0.0.

Chaque livraison trimestrielle *remplace* la précédente — URL, jeux de données, projets Postman ou SoapUI : les artefacts d'une version antérieure ne sont plus valables, et le wiki conserve les anciennes sections en lecture seule.

## Trois environnements, à ne pas confondre

Le gabarit DNS des annuaires centraux (voir [carte_des_tdd.md](carte_des_tdd.md#chapitre-3--les-sous-chapitres-qui-servent)) se termine par un segment d'environnement, et c'est lui qui distingue trois mondes sans rapport entre eux :

| Segment | Ce que c'est | Ce qu'on y voit |
| --- | --- | --- |
| `testing` | Les annuaires **simulés par la plateforme de test**, servis depuis l'hébergement Azure de l'équipe de test | Un jeu de données de référence fixe, et les modifications qu'on y dépose soi-même, visibles de soi seul |
| `acc` | L'**acceptation** : la vraie implémentation des Common Services par la Commission, avant production | Ce que les États membres y ont réellement inscrit — c'est l'environnement sur lequel ce dépôt travaille |
| `prod` | La production | — |

Les hôtes suivent tous la même règle : l'acceptation insère `acc` juste après le rôle. La **console d'administration** est l'interface graphique par laquelle un État membre inscrit à la main ce que l'interface LCM dépose par message — schémas de classification, types de justificatif, fournisseurs, déclarations de démarche ; elle demande un compte rattaché à un pays, ouvert par le [Service Desk](https://ec.europa.eu/digital-building-blocks/sites/display/OOTS/Service+Desk).

| | Acceptation | Production |
| --- | --- | --- |
| Console d'administration | `https://cs.acc.oots.tech.ec.europa.eu/` | `https://cs.oots.tech.ec.europa.eu/` |
| Interface de requête de l'EB et du DSD | `https://query.cs.acc.oots.tech.ec.europa.eu/` | `https://query.cs.oots.tech.ec.europa.eu/` |
| Semantic Repository | `https://sr.acc.oots.tech.ec.europa.eu/` | `https://sr.oots.tech.ec.europa.eu/` |

L'URL de requête, elle, **ne se code pas en dur : elle se résout** par NAPTR, et [carte_des_tdd.md](carte_des_tdd.md#chapitre-3--les-sous-chapitres-qui-servent) porte le gabarit et ses pièges.

> [!IMPORTANT]
> **Rien de ce qu'on dépose dans les Testing Services n'atteint un autre État membre.** Les annuaires de la plateforme de test sont des bouchons cloisonnés par code pays : deux équipes qui testent en parallèle ne voient pas les données l'une de l'autre, et une inscription réelle — celle qui manque à la France, voir [reste_à_faire.md](reste_à_faire.md) — passe par l'acceptation puis la production, pas par ici.

## La plateforme de test

Les Testing Services sont bâtis sur l'[Interoperability Test Bed](https://joinup.ec.europa.eu/collection/interoperability-test-bed-repository/solution/interoperability-test-bed) (ITB), le moteur de test générique de la Commission, sur lequel l'équipe OOTS greffe ses propres extensions — annuaires simulés, validateurs du modèle de données. OOTS dispose de sa propre instance, ouverte à **l'auto-inscription** par un jeton public que porte la page du wiki, pour éviter l'enrôlement sur l'instance principale.

L'usage suit toujours la même mécanique : on déclare un *système* (l'implémentation à tester), on lui attache des *déclarations de conformité* (un composant : requêteur AS4, client de l'Evidence Broker, LCM…), puis on joue les cas de test un par un, en pilotant en parallèle son propre outil — navigateur, Postman, SoapUI, ou sa propre implémentation. La plateforme attend l'appel au bon moment ; un appel décalé fait échouer le cas.

Chaque équipe se voit attribuer un **code pays à deux lettres** qui s'insère dans le chemin des URL d'annuaire — `…/eb/FR/rest/search?queryId=…`. Il n'a rien à voir avec le pays interrogé : il sert à la plateforme à rattacher un appel entrant à une session. Les URL de production n'en portent pas, si bien que l'URL de base d'un client de test diffère de celle qu'il emploiera pour de vrai.

> [!WARNING]
> **Aucune donnée personnelle ni sensible sur l'instance OOTS de l'ITB**, ni dans les comptes ni dans les jeux de test : elle n'offre pas le niveau de sécurité de l'instance principale. La plateforme n'est par ailleurs ouverte qu'en semaine, de 5 h à 20 h (heure de Bruxelles).

## Les composants

### 1. Le validateur de messages

Le seul composant utilisable **sans compte**, depuis un navigateur : on y colle un XML, on choisit un type, il rend un rapport téléchargeable en XML, PDF ou CSV. Il valide contre l'EDM v2.0.1 par défaut, et les versions antérieures restent servies à des URL distinctes — jusqu'à la 1.0.5.

En mode simple, il enchaîne validation XSD puis règles Schematron et listes de codes Genericode, sur tous les messages du système : requête, réponse, exception, réponses de l'EB et du DSD, messages LCM, entête ebMS, listes de codes, et depuis cette version les schémas de classification propres à un État membre. Les règles portent une gravité — `FATAL`, `WARNING`, et `CAUTION`, qui n'invalide pas le message. Une erreur XSD peut faire sauter le reste du contrôle : il faut la corriger avant de conclure quoi que ce soit des règles métier.

> [!NOTE]
> **Ce que le validateur en ligne apporte que `scripts/validate_schematron.sh` ne peut pas donner**, c'est la **validation croisée** : confronter une réponse à la requête qui l'a appelée, une seconde requête à l'exception qui l'a précédée, un message à son entête ebMS, ou une requête aux réponses d'annuaire dont elle est censée découler. Une vingtaine de couples sont proposés. Le contrôle local, lui, ne voit qu'un message à la fois — voir [README](../README.md#validation-des-messages-contre-les-règles-des-tdd). En mode croisé, les règles du mode simple ne sont pas rejouées : les deux passes se complètent.

### 2. L'interface de requête des annuaires (EB et DSD)

Des serveurs REST/RegRep bouchonnés, interrogeables anonymement en HTTPS — HTTP n'est plus accepté — pour voir varier les réponses au gré des paramètres, ou pour dérouler les cas de test de la plateforme. Des projets [Postman](https://www.postman.com/downloads/) et [SoapUI](https://www.soapui.org/downloads/soapui/) prêts à l'emploi accompagnent les deux annuaires, côté client (*Query Client*, ce que ce dépôt est) comme côté serveur.

Le projet SoapUI va jusqu'à vérifier la **signature détachée des réponses**, désormais en ECDSA, à l'aide des clés publiques publiées avec lui — la même bibliothèque et le même certificat valant pour tous les environnements non productifs. Le cas de la signature *invalide* ne peut se jouer qu'en session active : seule la plateforme sait produire une réponse mal signée.

> [!IMPORTANT]
> **L'entête `Accept-Version` n'est pas gérée par les annuaires de test** : la version rendue est celle de la livraison en cours, quoi qu'on demande. La négociation de version décrite dans [versions_tdd.md](versions_tdd.md) ne s'éprouve donc que sur l'acceptation.

### 3. La messagerie eDelivery AS4

L'équipe de test exploite deux instances de [Domibus](domibus_context.md) : un **C3** qui joue le correspondant étranger et qui est raccordé à la plateforme, et un **C2** d'exemple déjà configuré pour dialoguer avec lui. On peut envoyer vers le C3 sans être connecté à la plateforme, et vérifier chez soi l'accusé de réception AS4 ; recevoir, en revanche, demande une session active, puisque seul un cas de test déclenche un envoi vers son propre point d'accès.

Le raccordement n'est pas libre-service : il faut transmettre au bureau d'assistance OOTS son **certificat public et l'URL de son point d'accès**, et se voir attribuer en retour un `partyId` et son type par un administrateur. Le type de partie de la plateforme est `urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots` ; une équipe nationale peut employer le sien, EAS ou `unregistered`.

> [!IMPORTANT]
> **Depuis les TDD 2.0.0, l'entête AS4 porte deux propriétés obligatoires de plus — `ExchangeId` et `SpecificationId`** ([chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931)). Le PMode et les entêtes produits doivent les déclarer tous les deux, faute de quoi l'échange est rejeté.

### 4. L'interface LCM des annuaires

Le *Life Cycle Management* est l'interface par laquelle un État membre **écrit** dans l'Evidence Broker et le Data Service Directory, là où l'interface de requête ne fait que lire. Les cas de test partent d'un jeu de données de référence commun ; une soumission LCM en dérive un jeu propre à son code pays, que seules les requêtes portant ce code voient ensuite. Une fonction de restauration ramène au jeu de référence — indispensable, puisqu'une soumission réussie fait échouer tous les cas de test de l'interface de requête, qui attendent le jeu d'origine.

Les cas couvrent l'erreur (fichiers volontairement fautifs, à déposer tels quels) et le succès, entrée unique ou entrées multiples, DSD seul, EB seul, ou **soumission combinée EB + DSD**, celle-ci allant jusqu'aux schémas de classification et à leurs listes de codes. Le versionnement de ces listes y est éprouvé pour lui-même : retirer une valeur en service est refusé, en ajouter sans incrémenter la version est refusé, retirer une valeur inutilisée en incrémentant la version passe.

> [!IMPORTANT]
> **Le LCM de test ne se comporte pas comme celui de production**, et l'écart est délibéré, pour permettre un test composant par composant :
>
> | En test | En production |
> | --- | --- |
> | La soumission se fait par **dépôt de fichier** dans l'interface de la plateforme | Elle se fait **exclusivement par AS4** ; aucun dépôt de fichier n'est possible |
> | Les modifications ne sont visibles que des requêtes portant son propre code pays | Elles sont visibles de tous les États membres |
> | Une fonction de restauration rend le jeu de référence | Chaque modification est **définitive** |
> | Un État membre peut modifier les données d'un autre | Il ne le peut pas ; l'interface rejette la soumission entière |
>
> Les cas LCM ne se jouent donc pas hors plateforme. Une version future les fera passer par AS4, ce qui les rendra jouables en autonomie.

Autre conséquence du rythme trimestriel : **une évolution du modèle de données périme les soumissions LCM antérieures**. Elles sont archivées par l'équipe de test, restituables sur demande, mais à rejouer.

### 5. Espace de prévisualisation simple et scénarios de bout en bout

Le composant qui approche le plus un vrai correspondant hors [Projectathon](implementations_europeennes.md#les-projectathons--pourquoi-il-ny-a-pas-plus). La plateforme joue le fournisseur : elle reçoit la requête, la contrôle comme le ferait un observateur de Projectathon, renvoie une exception portant une URL de prévisualisation, sert un écran où l'on accepte ou refuse le justificatif, puis répond à la seconde requête par la réponse et sa pièce jointe.

Une quinzaine de scénarios sont proposés — sans prévisualisation, sans justificatif correspondant, erreur de registre de base, prévisualisation acceptée, refusée, expirée, justificatif PDF ou XML, empaquetage à plusieurs pièces, classification du fournisseur, personne morale — chacun décliné avec ou sans vérification explicite des trois appels d'annuaire qui précèdent l'échange. Les variantes « avec appels d'annuaire » exigent un code pays préfixé `P7`, pour séparer ces données de celles des cas ordinaires.

> [!NOTE]
> **Ce composant sert des données largement statiques** : la validation croisée des messages peut y achopper sans que l'implémentation testée soit en cause. La Commission le présente comme un premier palier, et recommande un test contre un vrai système d'un État membre partenaire avant toute mise en production.

### 6. La découverte DNS des annuaires (NAPTR)

Le gabarit et son mode d'emploi appartiennent à [carte_des_tdd.md](carte_des_tdd.md) ; ce composant ne fait qu'en publier les enregistrements pour l'environnement `testing`, à côté de ceux de l'acceptation. Rappel utile : ni un navigateur ni Postman ne résolvent un NAPTR, un composant dédié est nécessaire.

### 11. Tests de fonctionnalités particulières

Une base de connaissances ouverte, que les équipes nationales alimentent elles-mêmes. Trois sujets y figurent :

- **La réponse différée** — le fournisseur signale que le justificatif existera plus tard. Les discussions du sous-groupe en resserrent l'usage : la fonctionnalité vise le cas où le justificatif existe mais demande une numérisation, un paiement ou une manipulation, et suppose donc que l'usager soit identifiable côté fournisseur ; elle ne doit **pas** servir à signaler une fenêtre de maintenance, pour laquelle un code d'erreur est attendu. La reprise de la démarche, elle, incombe au portail de démarche : la plateforme intermédiaire ne conserve pas assez longtemps pour la porter.
- **Les schémas de classification propres à un État membre** — parcours pas à pas dans l'interface graphique des Common Services : déposer un schéma, en tirer un concept de classification, l'affecter à un type de justificatif puis à un fournisseur, relier les deux, et enfin retrouver le tout par une requête DSD, qui répond d'abord `DSD:ERR:0005` pour réclamer l'attribut manquant. Les mêmes schémas servent de juridiction dans une déclaration de démarche ou dans une liste de types de justificatif.
- **La détermination de sous-démarche** — filtrer les exigences d'une démarche qui en recouvre plusieurs (`X1`, les qualifications professionnelles). La Finlande l'a implémentée ; l'affaire est purement interne au requêteur, ses requêtes sortantes restant identiques.

## Peut-on y déposer démarches, exigences ou justificatifs ?

**Les démarches et les exigences, oui — mais pas au sens d'une inscription. Les justificatifs, jamais.**

- **Déclarations de démarche, exigences, types de justificatif, fournisseurs, services de données, schémas de classification** se déposent par l'interface LCM, sous forme d'un message *SubmitObjects* — c'est même l'objet du composant 4. Dans les Testing Services, ce dépôt se fait par **envoi de fichier depuis l'interface de la plateforme**, il n'est visible que des requêtes portant son propre code pays, il s'annule d'un appel de restauration, et une évolution du modèle de données le périme. C'est une **épreuve du format**, pas une publication : rien n'en sort vers un autre État membre.
- **Une inscription réelle** — celle qui manque à la France — se fait ailleurs : sur les Common Services d'acceptation puis de production, soit par l'interface LCM en AS4, soit à la main par l'interface graphique que la Commission fournit, celle que décrit le composant 11b (menus « For Providers » et « For Requesters »). C'est ce chemin-là qu'il faut emprunter pour que la France devienne interrogeable, et il ne demande pas de code.
- **Les justificatifs ne sont déposés nulle part.** Les annuaires centraux ne portent que des métadonnées — qui délivre quoi, où, sous quel format ; le document lui-même reste chez son fournisseur et ne voyage qu'en AS4, chiffré, d'un point d'accès à l'autre ([le modèle des quatre coins](oots_context.md#le-modèle-des-quatre-coins)). Aucun composant des Testing Services n'offre de les téléverser : ceux du composant 5 sont fixes et servis par la plateforme, et la seule façon d'en émettre un est de **jouer le rôle de fournisseur** dans un cas de test AS4, en répondant soi-même à une requête de la plateforme.

## Ce que ça change pour ce dépôt

- Le validateur en ligne est utilisable **tout de suite, sans compte**, et couvre la validation croisée que le contrôle Schematron local ne fait pas : c'est le complément naturel de `make schematron` après une modification des gabarits ou des builders.
- Les annuaires bouchonnés du composant 2 offrent un point de comparaison en regard de l'acceptation, que le dépôt interroge partout ailleurs — dans la suite unitaire sur réponses capturées, et pour de bon dans le [test de bout en bout](test_e2e.md#les-annuaires-centraux-sont-les-vrais).
- Le raccordement AS4 au C3 de la plateforme demande un échange de certificats avec l'équipe de test, et l'attribution d'un `partyId` : c'est une démarche à engager, pas une configuration à écrire.
- Le bureau d'assistance et le sous-groupe *Testing and deployment* sont les canaux prévus pour les questions ; le [Service Desk](https://ec.europa.eu/digital-building-blocks/sites/display/OOTS/Service+Desk) en donne les adresses.
