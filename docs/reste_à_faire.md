# Reste à faire pour atteindre les TDD v2.0

> Ce document mesure l'écart entre ce dépôt et la version **2.0.1 (juillet 2026)** des [Technical Design Documents](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/overview), la spécification européenne d'OOTS. Il dit ce qui manque, ce que chaque manque coûte, et dans quel ordre les aborder. Pour comprendre OOTS lui-même, lire d'abord [oots_context.md](oots_context.md) ; pour savoir pourquoi c'est la 2.0 qui est visée plutôt que la 1.2, [versions_tdd.md](versions_tdd.md) ; pour retrouver un chapitre des TDD, [carte_des_tdd.md](carte_des_tdd.md) ; pour un sigle ou un terme, [glossaire.md](glossaire.md).

## Comment lire ce document

Chaque chantier est présenté de la même façon : **ce que c'est** en langage courant, **ce que la spécification exige**, **ce que fait le dépôt aujourd'hui**, **ce qu'il faut construire**. Un lecteur non technique peut ne lire que le premier paragraphe de chaque chantier, la [synthèse par chapitre](#inventaire-chapitre-par-chapitre) et les [dépendances entre chantiers](#dépendances-entre-chantiers) : il en aura une image juste.

Ce document **ne propose pas d'ordre de travail**. Il décrit ce qui contraint techniquement l'enchaînement des chantiers ; l'arbitrage, lui, appartient à l'équipe.

Les **bouchons** sont les endroits où le code écrit une valeur en dur, faute d'avoir de quoi la calculer. Ils sont numérotés et cette numérotation est citée dans les commentaires du code ; **elle ne doit pas changer sans mettre à jour ces commentaires**.

## Où en est le dépôt aujourd'hui

Le protocole fonctionne. Une requête part de France vers un correspondant étranger et une réponse revient ; une requête étrangère arrive en France et reçoit une réponse. Les messages sont construits et lus au format exigé, transportés par une passerelle eDelivery réelle, et validés contre les règles Schematron officielles de la 2.0. L'échange asynchrone — la réponse revient sur une autre connexion, parfois longtemps après — est en place, avec la `Conversation` qui relie les deux moitiés.

Les trois annuaires centraux sont désormais interrogés pour de vrai : découverte DNS, signature des réponses vérifiée, version négociée. Chaque échange laisse par ailleurs une trace conservée douze mois, comme l'article 17 l'impose. Ce qui manque n'est presque jamais le protocole : ce sont les **raccordements au monde réel**. Le dépôt parle correctement, mais au nom d'une identité qui n'a pas été authentifiée, et il n'a aucun justificatif réel à fournir — ni, faute d'inscription au DSD, d'existence pour qui voudrait l'interroger. Un échange complet, aujourd'hui, ne transporte qu'un PDF d'exemple pour la démarche de vérification système.

> [!IMPORTANT]
> Le système n'est pas homologué. Le requêtage reste verrouillé en production par la variable `AVEC_REQUETE_PIECE_JUSTIFICATIVE` : ne pas l'activer avant homologation. Aucun des chantiers ci-dessous ne lève cette réserve à lui seul.

## Les dix chantiers

Classés par poids décroissant. Les trois premiers sont des conditions d'existence : sans eux, aucun échange réel n'est possible, quelle que soit la qualité des messages. Le dixième est le seul qui ne mesure pas un écart aux TDD.

### 1. Les Common Services

**Ce que c'est.** Les trois annuaires centraux que sont l'**Evidence Broker**, le **Data Service Directory** et le **Semantic Repository** (définis au [glossaire](glossaire.md)) répondent aux questions qu'un pays demandeur se pose avant d'émettre sa requête. Sans eux, il devrait connaître par avance l'organisation de tous les autres — ce qui est précisément ce qu'OOTS existe pour éviter.

**Ce qu'exige la spécification.** Le [chapitre 3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932907) définit trois appels REST : deux vers l'Evidence Broker ([3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939)) et un vers le Data Service Directory ([3.1.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957)). L'instance à interroger se **découvre par le DNS** ([3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916)) : chaque État membre a le choix entre l'instance de la Commission et la sienne, et le client doit résoudre un enregistrement NAPTR pour savoir à laquelle s'adresser. Les réponses portent une **signature détachée** que le client doit vérifier, et la version attendue se négocie par un en-tête `Accept-Version` ([3.6.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954)).

**Ce que fait le dépôt.** Les trois appels sont branchés sur les annuaires réels. L'instance à interroger est découverte par NAPTR (`CommonServicesInstance`), les requêtes portent `Accept-Version: oots-cs:v2.0`, la **signature détachée de chaque réponse est vérifiée** contre les racines publiques de la Commission (`CommonServicesSignature`), et les réponses sont mises en cache. `Directories::CommonServices` n'est plus qu'une façade au-dessus de `EvidenceBrokerClient` et `DataServiceDirectoryClient`. Le bouchon 1 est levé, et le bouchon 2 avec lui : le DSD fournit le point d'accès.

**Ce qui reste.** Trois conséquences, que ce raccordement rend possibles sans les traiter :

- **Le choix de l'usager.** Quand plusieurs types de justificatif ou plusieurs fournisseurs conviennent, les TDD veulent que l'usager tranche. Le code garde le premier de la liste, silencieusement — `EvidenceRequest::ResolveEvidenceType` et `EvidenceRequest::ResolveProvider`. La requête émise reste valide : elle demande l'une des preuves qui conviennent, au lieu de laisser choisir.
- **Les exigences suivantes de la démarche, elles, sont perdues.** `Directories::CommonServices#first_requirement` ne garde que la première exigence rendue par l'Evidence Broker, et ce raccourci-là n'est pas du même ordre que le précédent : plusieurs exigences d'une même démarche ne sont pas des alternatives. Le [chapitre 3.2.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) ne donne d'opérateur logique qu'un cran plus bas — « *Evidence Types of an Evidence Type List are combined via the logic operator "AND". Evidence Type Lists that fulfill the same Requirement are combined via the logic operator "OR"* » —, et n'en donne aucun entre exigences ; sa règle du `NoMatch`, qui oblige un État membre à déclarer une liste vide plutôt qu'à omettre une exigence qu'il ne peut pas satisfaire, suppose que chacune reçoit une réponse. La Slovénie déclare ainsi deux exigences sous `S1` — une preuve de naissance **et** une preuve de citoyenneté —, dont l'application ne demanderait que la première. Une requête à laquelle il manque une preuve n'est pas une requête dégradée, c'est une requête à laquelle la démarche ne peut pas aboutir.
- **Le dialogue de désambiguïsation.** Quand un pays a plusieurs fournisseurs pour un même justificatif, le DSD répond une erreur `DSD:ERR:0005` qui demande une précision à poser à l'usager — « dans quelle ville êtes-vous né ? ». L'erreur est reconnue et remontée telle quelle ; la question n'est pas posée.
- **Le Semantic Repository comme service.** Il reste consulté à la conception, pas à l'exécution — ce que la spécification prévoit.
- **La recherche de la console n'a aucun filet.** `app/assets/javascripts/filter.js` porte tout ce qui trie une liste sous les doigts d'un opérateur — normalisation des accents, découpage en mots, correspondance par préfixe, réécriture du décompte — et aucun test ne l'exerce : les specs de requête vérifient que les attributs sont posés sur les bons éléments, jamais que taper « konig » retrouve « Königreich ». Le couvrir demande un navigateur : `cuprite` et `capybara` sont au `Gemfile`, mais l'image de test n'embarque pas de Chrome, quand l'`ubuntu-latest` de l'intégration continue en a un. Une spec système coûte donc une étape Docker dédiée aux tests, pour ne pas alourdir de trois cents mégaoctets une image qui sert aussi au service web.

**La négociation de version, elle, est faite**, et n'a pas demandé de code de tri : le mécanisme et ce que le dépôt en fait sont décrits dans [versions_tdd.md](versions_tdd.md).

> [!IMPORTANT]
> **La France n'est pas inscrite au Data Service Directory**, ni en acceptation ni en production. Elle a pourtant un type de justificatif publié au Semantic Repository et rattaché à l'exigence de test dans l'Evidence Broker : il ne manque que l'entrée DSD, celle qui porte le point d'accès. Tant qu'elle manque, aucun pays ne peut interroger la France, et une requête réelle échoue sur `DSD:ERR:0001`, rendu en `422`. C'est un travail de raccordement, pas de code. Le test de bout en bout, lui, double les deux annuaires pour continuer à couvrir le transport — voir [test_e2e.md](test_e2e.md#les-annuaires-centraux-sont-doublés).

### 2. L'identité de l'usager

**Ce que c'est.** OOTS transporte des données personnelles d'une administration à une autre. Ce qui autorise ce transport, c'est que l'usager s'est authentifié avec une identité numérique reconnue dans toute l'Union — **eIDAS** — et que les attributs issus de cette authentification voyagent dans la requête, permettant à l'administration étrangère de retrouver la bonne personne dans ses propres registres.

**Ce qu'exige la spécification.** Le [chapitre 2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932912) impose que le demandeur authentifie l'usager par un moyen d'identification notifié, et joigne à la requête les attributs obtenus ainsi que le **niveau de garantie** de ce moyen. La requête doit pouvoir décrire une personne physique, une personne morale, et les cas de représentation — un dirigeant agissant pour sa société, un tiers agissant pour un particulier.

**Ce que fait le dépôt.** Le fournisseur de service français transmet le bénéficiaire dans un jeton chiffré, qu'il signe. Cette signature atteste **qui a envoyé le jeton**, jamais que cet émetteur avait qualité pour agir au nom du bénéficiaire déclaré ; l'annuaire des requêteurs autorisés tient lieu de garde-fou. Le niveau de garantie est écrit en dur à `High`. C'est le **bouchon 4**. Par ailleurs, seule la personne physique est modélisée : ni personne morale, ni représentant.

**Ce qu'il faut construire.** Le raccordement à un nœud eIDAS, ou à FranceConnect+ selon le cadre retenu, est la pièce maîtresse et dépasse ce dépôt. À son échelle, il reste : modéliser la personne morale et les deux formes de représentant ; porter les attributs facultatifs qui améliorent la réconciliation (nom de naissance, lieu de naissance, adresse, nationalité) ; appliquer la liste des pays dont l'identifiant unique ne doit **pas** être transmis, parce qu'il est dérivé par pays destinataire et n'aurait aucun sens ailleurs ; et transporter l'attribut sectoriel qui exprime l'étendue d'un pouvoir de représentation.

### 3. La prévisualisation

**Ce que c'est.** Le règlement donne à l'usager le droit de **voir le justificatif avant qu'il ne serve**, et de refuser qu'il serve. Ce droit s'exerce chez le pays qui fournit le document, pas chez celui qui le demande : l'usager quitte le portail de démarche, va voir son document sur un site étranger, décide, puis revient. C'est le seul endroit de tout OOTS où un humain est devant un écran.

**Ce qu'exige la spécification.** Le [chapitre 4.9](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) décrit deux échanges successifs. Le premier reçoit en réponse une erreur particulière portant l'adresse de l'espace de prévisualisation. Le second, envoyé pendant que l'usager consulte, recopie cette adresse et ajoute — c'est une nouveauté de la 2.0 — l'**adresse de retour** vers laquelle renvoyer l'usager. La réponse à ce second échange n'arrive qu'une fois l'usager décidé, et ne contient que ce qu'il a accepté. Les deux échanges se corrèlent par le même identifiant d'échange.

**Ce que fait le dépôt.** Côté demandeur, la moitié du chemin est faite : l'erreur de redirection est reconnue, l'adresse de prévisualisation est extraite, son schéma est vérifié — un correspondant ne peut pas y glisser un `javascript:` — et elle est rendue à l'appelant. Mais **le second échange n'est jamais émis** : ni le slot d'adresse de prévisualisation, ni celui d'adresse de retour n'existent dans le gabarit de requête, aucune adresse de retour n'est fabriquée, et l'identifiant d'échange n'est pas conservé sur la conversation pour être réutilisé. Côté fournisseur, il n'y a **aucun espace de prévisualisation** : la France répond immédiatement, même quand la requête déclare la prévisualisation nécessaire. C'est le **bouchon 5**.

**Ce qu'il faut construire.** Côté demandeur : les deux slots, la fabrication d'une adresse de retour à usage unique et à durée limitée, le point d'entrée qui accueille le retour, et la reprise de la démarche là où l'usager l'avait laissée. Côté fournisseur : un espace de prévisualisation complet — c'est la seule interface humaine du dépôt, et le seul endroit où les règles d'accessibilité s'appliquent.

> [!WARNING]
> Tant que la prévisualisation manque côté fournisseur, la France ne peut pas servir un justificatif portant sur une personne physique dans le cas général : les TDD interdisent de renvoyer le document sans prévisualisation quand la requête la déclare requise. La démarche de vérification système y échappe parce qu'elle ne transporte aucune donnée réelle.

### 4. Le fournisseur de données français

**Ce que c'est.** Quand un pays étranger demande un justificatif à la France, il faut bien que quelqu'un le détienne. C'est le rôle d'une administration ou d'un opérateur national — l'API Diplômes pour un diplôme, l'état civil pour un acte de naissance.

**Ce qu'exige la spécification.** Le [chapitre 1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932911) attend d'un *Data Service* qu'il valide la requête, retrouve la personne dans ses registres, et rende le document accompagné de ses métadonnées — émetteur, date d'émission, type, période de validité.

**Ce que fait le dépôt.** Pour la démarche `00`, la vérification système d'OOTS, la France renvoie un PDF d'exemple ; toute autre démarche reçoit une erreur « objet introuvable ». La date d'émission du document est écrite en dur, faute d'un vrai document à dater. C'est le **bouchon 3**.

**Ce qu'il faut construire.** Un client par fournisseur de données raccordé, et la réconciliation d'identité qui va avec : les TDD imposent qu'en l'absence de correspondance **unique**, aucun justificatif ne soit renvoyé et une erreur soit émise. Zéro correspondance et deux correspondances se traitent pareil : par un refus.

### 5. Le contenu des messages

**Ce que c'est.** Deux moitiés dissymétriques. À l'écriture, les messages ont la bonne enveloppe, les champs obligatoires et — depuis que le bouchon 7 est levé — l'exigence et le service de données que les annuaires ont nommés ; d'autres éléments, introduits ou étendus en 2.0, ne sont toujours pas écrits. À la lecture, le dépôt prend ce dont il a besoin et ne contrôle pas le reste — c'est la moitié la moins visible, et celle qui laisse passer des messages non conformes sans rien dire.

**Ce qu'exige la spécification.** Le [chapitre 4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) détaille la requête slot par slot ; le [chapitre 4.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) donne les règles qu'un message doit satisfaire, dans les deux sens.

La requête déclare désormais l'exigence que l'Evidence Broker publie, avec son nom et sa description, et reprend du Data Service Directory le contenu de son `DataServiceEvidenceType` — identifiant du service, classification, titres, descriptions et distribution, langue comprise. Le [chapitre 4.5.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) lui en fait omettre le niveau de garantie, que seule la console lit. Ce qui manque encore :

| Élément | Aujourd'hui | Attendu |
| --- | --- | --- |
| `DistributedAs/ConformsTo` | Absent | Le **profil de conformité** d'un justificatif structuré, que le Data Service Directory publie et que la France ne demande pas encore |
| `AssociatedDocumentRequest` | Absent | Demander en même temps une annexe, une traduction ou une version lisible par un humain — nouveauté 2.0 |
| `EvidenceProviderClassification` | Absent | La précision fournie par l'usager pour désigner le bon fournisseur, en réponse à un `DSD:ERR:0005` (voir chantier 1) |
| `PreviewLocation`, `ReturnLocation` | Absents | Requis dans le second échange de la prévisualisation (voir chantier 3) |
| `LegalPerson`, `AuthorizedRepresentative` | Absents | Requis dès qu'une démarche porte sur une personne morale (voir chantier 2) |

Du côté de la réponse ([4.5.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951)), l'empaquetage introduit en 2.0 est en place dans sa forme minimale — un paquet, un justificatif principal, correctement classé. Ce qu'il ne sait pas encore faire : joindre des **documents complémentaires** (annexe, traduction, version lisible) et déclarer leur lien avec le justificatif principal ; déclarer une réponse **différée**, quand le document existe mais ne sera disponible que plus tard ; porter la langue, le profil de conformité et la période de validité.

#### Et symétriquement, ce qu'on lit

La validation des messages reçus est bien plus mince que leur écriture, et c'est le manque le moins visible de tout ce document : le dépôt lit ce dont il a besoin, et ne vérifie pas le reste.

Concrètement, une requête étrangère est aujourd'hui acceptée dès lors que les quelques champs que le code consulte sont présents. Une requête sans `PossibilityForPreview`, sans `ExplicitRequestGiven`, déclarant à la fois une personne physique et une personne morale, ou annonçant une version de spécification que le corps du message contredit, est traitée sans broncher. Les règles du [chapitre 4.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) et celles de l'en-tête de transport ([4.7.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932948)) ne sont vérifiées que sur les messages **produits**, par Schematron, jamais sur ceux reçus.

Quatre contrôles manquent, tous assortis d'une réponse d'erreur précise :

- **Valider la requête reçue contre les règles métier** et refuser par un `EDM:ERR:0003` ce qui les enfreint. Les TDD prévoient explicitement que les violations de l'en-tête soient signalées ainsi, et non par une erreur de transport.
- **Dire ce qui n'allait pas.** L'attribut `detail` de l'exception existe pour porter la règle violée ; le dépôt ne l'écrit jamais, ni dans son modèle d'exception ni dans son gabarit. Un correspondant reçoit donc « requête syntaxiquement ou sémantiquement invalide » et rien d'autre — de quoi rendre un diagnostic impossible à distance.
- **Rejeter une requête déjà traitée.** Le [chapitre 4.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) impose qu'un identifiant de requête ne serve qu'une fois et qu'un fournisseur refuse les répétitions. Rien ne les détecte.
- **Vérifier qu'une réponse répond bien à la requête envoyée.** Le même chapitre corrèle réponse et requête par l'identifiant de requête. Le dépôt, lui, ne retrouve la conversation que par l'identifiant de conversation : l'identifiant de requête est lu, renvoyé, mais **jamais conservé**, donc jamais comparé. Une réponse portant un identifiant de requête qui n'est pas le nôtre serait acceptée.

À quoi s'ajoute, sur le contenu même : le dépôt ne lit pas les métadonnées du justificatif reçu, et **ne vérifie pas que la personne décrite dans la réponse est celle qui figurait dans la requête** — un contrôle que la spécification demande explicitement.

### 6. Les justificatifs structurés

**Ce que c'est.** Un PDF se lit par un humain ; une administration qui le reçoit doit ressaisir ce qu'il contient. Un justificatif **structuré** est le même document exprimé en données, exploitable directement. C'est l'apport principal de la 2.0, et ce qui permet aussi de n'envoyer que ce qui est nécessaire — un extrait de l'acte de naissance plutôt que l'acte entier.

**Ce qu'exige la spécification.** Les [chapitres 3.3](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920) et [5](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932910) décrivent les modèles de données publiés au Semantic Repository et la méthode pour en définir. Un justificatif structuré déclare le modèle auquel il se conforme, par une URL stable. Un format structuré sans modèle correspondant doit être accompagné d'une version lisible par un humain.

**Ce que fait le dépôt.** Rien : le seul format traité de bout en bout est le PDF, écrit en dur aussi bien dans la lecture des messages reçus que dans le type de pièce jointe attendu. C'est le **bouchon 8**.

**Ce qu'il faut construire.** Élargir la chaîne aux formats de la liste officielle, gérer plusieurs pièces jointes dans un même message, et porter puis vérifier la déclaration de conformité au modèle.

### 7. La journalisation et la non-répudiation

**Ce que c'est.** Le règlement d'exécution impose de garder trace de chaque échange pendant douze mois : qui a demandé quoi, à qui, quand, et ce qui a été répondu. Cette trace sert aux audits, aux contrôles de sécurité, et à trancher un litige — prouver qu'un document a bien été envoyé, et qu'il n'a pas été modifié en route.

**Ce qu'exige la spécification.** Le [chapitre 4.8](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) énumère, composant par composant, les données à journaliser et les identifiants qui permettent de recoudre un échange à partir de traces éparses. Il décrit aussi comment la non-répudiation se reconstitue, en remontant de l'identifiant d'un justificatif jusqu'à l'empreinte signée de son contenu.

**Ce que fait le dépôt.** Le journal existe : une table dédiée en ajout seul, écrite sur les deux chemins et sur les refus qui n'atteignent jamais la passerelle, avec le sujet du justificatif chiffré au repos et une purge à douze mois. Le PMode garde de son côté les métadonnées et les accusés signés aussi longtemps, là où il efface le justificatif aussitôt. Tout cela est décrit par [journal_des_echanges.md](journal_des_echanges.md), qui en est le propriétaire. Le bouchon 6 est levé.

L'[espace d'administration](espace_administration.md) rend l'état d'une conversation lisible — statut, code d'erreur EDM, raison de l'échec — mais **il ne fait pas office de journal**, et n'en montrera pas : il s'interdit toute donnée personnelle, et le journal en porte.

**Ce qui reste.**

- **La non-répudiation ne se rejoue pas encore de bout en bout.** Le journal donne de quoi parcourir la chaîne du chapitre — identifiant de message, de requête, de réponse, et l'empreinte du justificatif —, mais rien n'automatise le trajet jusqu'au `ds:SignedInfo` que la passerelle a signé. Le faire suppose de lire les métadonnées de non-répudiation de Domibus, que le plugin WS n'expose pas telles quelles.
- **La couche protocole reste chez la passerelle.** Accusés AS4 et *SOAP faults* vivent dans la base de Domibus ; les deux journaux se recousent à la main, par le `MessageId`.
- **Rien n'est exposé.** La lecture se fait à la console ou au `psql`. Une interface d'exploitation demanderait d'abord de décider qui peut voir des données personnelles, et l'espace d'administration n'est pas cet endroit.
- **Trois arrivées ou départs ne laissent aucune ligne**, faute d'avoir de quoi la qualifier ou d'un endroit où l'écrire : une enveloppe SOAP illisible, une action ebMS inconnue, et l'échec de soumission de la réponse française — `EvidenceProvision::AnswerRequest` journalise après `submit`, donc une panne de la passerelle emporte la trace de la tentative.
- **L'écriture suit l'effet qu'elle relate.** Le justificatif est remis, puis consigné ; la requête est soumise, puis consignée. Un échec d'écriture laisse donc un fait accompli sans trace, et le rejouer est impossible — la passerelle a effacé le message. L'ordre inverse aurait le défaut symétrique, consigner ce qui n'a pas eu lieu ; trancher demande de décider ce qu'on préfère perdre, et cela ne se décide pas en écrivant le journal.

### 8. Les délais d'expiration

**Ce que c'est.** Un échange qui implique un humain peut durer une heure ; un échange automatique doit échouer vite. Sans délais convenus, un demandeur attend indéfiniment une réponse qui ne viendra pas, et un fournisseur garde ouverts des liens qui devraient être périmés.

**Ce qu'exige la spécification.** Le [chapitre 4.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) fixe trois intervalles — cinq minutes pour le premier aller-retour, quinze pour que l'usager suive le lien, quarante pour qu'il consulte et décide — chacun majoré d'une minute côté demandeur, pour absorber le transport. Un fournisseur qui dépasse son délai doit renvoyer une erreur d'expiration plutôt que rien ; un demandeur qui dépasse le sien doit conclure à l'échec.

**Ce que fait le dépôt.** Aucun délai n'est configuré ni surveillé. Une conversation dont la réponse ne revient jamais reste indéfiniment en cours.

**Ce qu'il faut construire.** Des délais configurables, un travail de fond qui clôt les conversations expirées, et l'émission de l'erreur d'expiration côté fournisseur.

### 9. Les finitions eDelivery

**Ce que c'est.** Le transport lui-même, assuré par la passerelle Domibus, est déjà conforme pour l'essentiel. Restent des points de détail, mais qui sont des règles fermes.

**Ce qu'il faut construire** :

- **Vérifier la cohérence de version à l'entrée.** La 2.0 fait voyager la version deux fois : dans l'en-tête de transport et dans le corps du message. Elles doivent concorder, et un message où elles divergent doit être **rejeté**. Le dépôt écrit bien les deux, mais ne contrôle pas celles qu'il reçoit.
- **Distinguer conversation et échange.** En 2.0, l'identifiant de conversation désigne un **usager et sa session**, et peut couvrir plusieurs justificatifs demandés à la suite ; l'identifiant d'échange désigne un aller-retour. Le dépôt en crée un de chaque par requête, ce qui les confond. La distinction devient nécessaire dès la prévisualisation, où les deux échanges partagent le même identifiant d'échange.
- **La découverte dynamique par SMP** est facultative en 2.0 et annoncée comme obligatoire par la suite. À prévoir, pas à faire maintenant.

### 10. Ce que l'appelant apprend d'un échec

**Ce que c'est.** Le seul chantier de cette liste qui ne soit pas un écart aux TDD. Les spécifications ne disent rien de l'interface entre un fournisseur de service français et cette application — elles s'arrêtent aux frontières nationales. C'est donc une dette de conception, pas un défaut de conformité ; elle est ici parce qu'elle se paie au même endroit que le reste.

**Le problème.** Un échange peut mourir sans qu'aucun correspondant étranger ait répondu : la passerelle est injoignable, le message reçu est illisible, la conversation expire. Le fournisseur de service relit alors l'état de sa conversation et n'y lit **que le statut**. La raison est pourtant enregistrée — la colonne `error_description` existe et est remplie — mais elle n'est exposée nulle part, et le code d'erreur EDM reste vide puisqu'aucun correspondant n'en a fourni. Un intégrateur voit son échange échouer sans jamais savoir pourquoi.

**Ce qu'il faut trancher.** Ce qui remonte à l'appelant, et sous quelle forme : la description brute est écrite pour un journal, pas pour un tiers, et peut nommer des détails d'infrastructure. Il faut donc décider d'un vocabulaire d'erreurs stable côté interface nationale, distinct des messages internes.

**Un nettoyage à faire au passage.** Le traitement d'un message entrant rattrape la famille `EbmsError`, qui signifie *l'appel du fournisseur de service français est fautif* et vaut un 422. Toutes ses sous-classes naissent pendant cet appel, donc sur le chemin sortant : aucune ne peut survenir à l'arrivée d'un message. Le filet est vide et gagne à être resserré — c'est ce qui reste d'un questionnement plus large, dont la vraie substance est au [chantier 5](#et-symétriquement-ce-quon-lit) pour la validation, et ici pour la restitution.

**Ce dont ce chantier ne dépend pas.** De la journalisation : la raison de l'échec est écrite sur la conversation, et l'exposer ne demande rien de plus. Que le [journal](journal_des_echanges.md) la consigne aussi ne change pas la question posée ici. Les deux chantiers se ressemblent — tous deux décident du sort d'un incident — mais ils écrivent dans des endroits différents, pour des destinataires différents et avec des contraintes différentes : un appelant veut un code stable tout de suite, un auditeur veut une trace complète pendant douze mois. La seule chose à coordonner, si les deux se font, est le vocabulaire employé de part et d'autre — dans un sens comme dans l'autre.

## Les bouchons en place

Récapitulatif des valeurs écrites en dur, avec l'endroit où les remplacer. **Cette numérotation est citée dans les commentaires du code.**

| N° | Bouchon | Où | Remplacé par |
| --- | --- | --- | --- |
| 3 | Le justificatif français : un PDF d'exemple et une date d'émission fixe | `EvidenceProvision::AnswerRequest`, `SystemCheckResponseBuilder::ISSUING_DATE` | Chantier 4 |
| 4 | L'identité et l'autorisation : niveau de garantie fixe, annuaire de requêteurs autorisés | `NaturalPerson::LEVEL_OF_ASSURANCE`, `BeneficiaryToken`, `Directories::EvidenceRequesters` | Chantier 2 |
| 5 | La prévisualisation : second échange jamais émis, aucun espace côté fournisseur | `EvidenceRequestBuilder`, `IncomingMessage::SettleConversation` | Chantier 3 |
| 8 | Le PDF comme seul format traité | `RetrievedMessageParser::PDF`, `Attachment::MIME_TYPE`, `EvidenceType::PDF` | Chantier 6 |
| 9 | Le filet à erreurs vide du chemin entrant, et la raison d'un échec jamais rendue à l'appelant | `IncomingMessage::Process`, `EvidenceRequestsController#state_of` | Chantier 10 |

## Ce qui est déjà conforme

À ne pas refaire, et à ne pas casser en avançant :

- La structure des trois messages et leurs valeurs figées, validées par les règles Schematron officielles de la 2.0.
- Les nouveautés 2.0 déjà adoptées : l'identifiant d'échange et l'identifiant de spécification dans l'en-tête de transport, l'empaquetage de la réponse dans sa forme minimale.
- Le modèle des quatre coins, y compris l'inversion des rôles sur la réponse.
- Les huit codes d'erreur, transcrits de la liste officielle, et le cas particulier qui redirige vers la prévisualisation.
- L'échange asynchrone : la réponse revient sur une autre connexion, l'appelant reçoit aussitôt un identifiant, et la conversation relie les deux moitiés sans qu'aucun processus n'attende.
- L'identification des organisations françaises par leur SIRET, avec le schéma d'identifiant que les TDD imposent.

## Inventaire chapitre par chapitre

| Chapitre | État | Ce qui manque |
| --- | --- | --- |
| [1 — Architecture](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932911) | Partiel | Les deux rôles existent ; l'espace de prévisualisation, non |
| [2 — Identité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932912) | Absent | eIDAS, personne morale, représentation, réconciliation |
| [3.1 — DSD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932957) | Partiel | Le dialogue de désambiguïsation `DSD:ERR:0005` |
| [3.2 — Evidence Broker](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932939) | Conforme | — |
| [3.3 — Semantic Repository](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932920) | Absent | Modèles de données structurés |
| [3.4 — Distribution](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) | Partiel | Découverte DNS et cache faits ; le cache mandataire reste une option de déploiement |
| [3.5 — Listes de codes](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932952) | Partiel | Seuls les codes d'erreur sont transcrits ; les autres listes ne sont ni chargées ni vérifiées |
| [3.6 — API commune](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) | Conforme | — |
| [3.7 — Sécurité](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) | À vérifier | Profil TLS à confronter à la configuration réelle |
| [3.8 — Journalisation des annuaires](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932917) | Hors périmètre | Ne concerne que l'opérateur d'un annuaire |
| [4.4 — Modèle de requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932919) | Partiel | Délais d'expiration ; distinction conversation / échange ; unicité et corrélation des identifiants de requête |
| [4.5.1 — Requête](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932961) | Partiel | Voir le tableau du chantier 5 |
| [4.5.2 — Réponse](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932951) | Partiel | Documents complémentaires, réponse différée, langue et conformité |
| [4.5.3 — Erreur](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932938) | Conforme | — |
| [4.6 — Règles métier](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) | Partiel | Vérifiées par Schematron sur les messages **produits** ; aucune validation des messages **reçus** |
| [4.7 — eDelivery](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) | Partiel | Contrôle de cohérence de version en entrée ; SMP à prévoir |
| [4.8 — Journalisation des échanges](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932926) | Partiel | La couche métier est écrite et conservée douze mois ; la chaîne de non-répudiation ne se rejoue pas automatiquement |
| [4.9 — Prévisualisation](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932935) | Partiel | Second échange, adresse de retour, espace de prévisualisation |
| [5 — Modèles de données](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932910) | Absent | Dépend d'un justificatif réel à modéliser |
| [6 — Guidance et UX](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932909) | Sans objet | Rien de normatif |

## Dépendances entre chantiers

L'ordre dans lequel mener ces chantiers est un arbitrage — de calendrier, de moyens, de priorité politique — et il appartient à l'équipe. Cette section n'en propose aucun : elle décrit seulement **ce qui contraint réellement**, pour que la décision se prenne en connaissance de cause. Tout ce qui n'apparaît pas ici est libre.

### Tableau des dépendances

| Chantier | Ne peut aboutir qu'après | Son achèvement débloque |
| --- | --- | --- |
| 1. Common Services | *fait* | 5 (écriture), 6 |
| 2. Identité de l'usager | Une décision hors dépôt : quel fournisseur d'identité | Rien de bloqué, mais donne leur valeur aux attributs de 3, 4 et 5 |
| 3. Prévisualisation — côté demandeur | 9 (distinction conversation / échange) | Rien |
| 3. Prévisualisation — côté fournisseur | 4 (avoir un document à montrer) | Rien |
| 4. Fournisseur de données français | Un raccordement hors dépôt : accord et interface d'un détenteur | 3 (côté fournisseur), 6 |
| 5. Contenu des messages — écriture | 1, pour les champs qui viennent des annuaires | Rien |
| 5. Contenu des messages — lecture et validation | — | Rien |
| 6. Justificatifs structurés | 1, 4, et un modèle de données convenu au niveau européen | Rien |
| 7. Journalisation | *fait* | Rien de bloqué, mais 5 (lecture) s'appuie sur le journal pour la mémoire des requêtes déjà traitées |
| 8. Délais d'expiration — délai global d'un aller-retour | — | Rien |
| 8. Délais d'expiration — les trois intervalles T1/T2/T3 | 3 (les intervalles se définissent autour du flux de prévisualisation) | Rien |
| 9. Finitions eDelivery | — | 3 (côté demandeur) |
| 10. Restitution des erreurs | — | Rien |

### Ce qui peut démarrer aujourd'hui, sans rien attendre

Quatre lots ne dépendent d'aucun autre chantier ni d'aucun tiers, et peuvent donc être menés en parallèle ou dans n'importe quel ordre :

- **La validation des messages reçus** (chantier 5, seconde moitié). Le [chapitre 4.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932928) n'assigne le devoir de validation à personne et présente les Schematron comme une preuve de conformité — « *Schematrons are used to prove the correctness of instances* » —, pas comme un composant d'exécution : le mécanisme est à notre main, et `.schematron/` est de toute façon un cache téléchargé dont le XSLT 2.0 est hors de portée de Nokogiri.
- **Les délais d'expiration** (chantier 8), dans leur forme simple — le délai global d'un aller-retour.
- **Les points de finition eDelivery restants** (chantier 9) : le contrôle de cohérence de version à l'entrée, et la distinction entre identifiant de conversation et identifiant d'échange.
- **La restitution des erreurs à l'appelant** (chantier 10). La raison de l'échec est déjà enregistrée : il s'agit de décider ce qu'on en montre.

### Ce qui ne dépend pas de ce dépôt

Deux chantiers n'avancent pas par le seul code, et leur délai est celui d'accords à obtenir :

- **L'identité** (chantier 2) suppose de trancher le fournisseur d'identité et de s'y raccorder.
- **Le fournisseur de données** (chantier 4) suppose l'accord d'un détenteur de justificatifs et l'accès à son interface.

Aucun autre chantier n'est *bloqué* par eux, mais leur absence prive de sens ce que les autres transportent : un niveau de garantie écrit en dur reste écrit en dur quelle que soit la qualité du message qui le porte.

### Les contraintes qui ne sont pas des dépendances

Deux faits pèsent sur le choix sans le déterminer, et méritent d'être posés tels quels :

- **La journalisation touchait tous les chemins du code**, ce qui est la raison pour laquelle elle a été menée avant le reste : la mener tard aurait signifié repasser sur du code fraîchement écrit. Le même argument vaut pour les délais d'expiration du chantier 8.
- **La validation de ce qu'on reçoit décide de ce qu'un correspondant peut diagnostiquer.** Sans elle, un pair qui échoue à échanger avec la France reçoit « requête invalide » sans autre indice. Cela n'empêche aucun développement, mais pèse sur ce que coûte un test pair-à-pair.

> [!NOTE]
> Un préalable ne relève d'aucun chantier : vérifier auprès du Service Desk que les outils de validation et le prochain Projectathon acceptent la v2.0. Développer contre une spécification qu'on ne peut pas faire valider par un pair est le seul risque sérieux du choix de version — il est détaillé dans [versions_tdd.md](versions_tdd.md).
