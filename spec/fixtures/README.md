# Fixtures de référence

Ces fichiers ont été produits par l'application **Node**, juste avant sa suppression, et constituent le cahier des charges exécutable de la réécriture en Rails. Ils ne sont pas des exemples : ce sont des attendus, que la suite compare.

> [!NOTE]
> La comparaison porte sur le **document**, non sur les octets : ordre, noms, espaces de noms, attributs et texte, en ignorant les blancs entre éléments et en normalisant les UUID par ordre d'apparition. Les octets de référence portent en effet des artefacts de l'interpolation qui les a produits, qu'aucune spécification ne demande. Les charges encodées en base64 sont décodées avant d'être comparées, faute de quoi la comparaison porterait sur leur indentation. Voir `spec/support/xml_matchers.rb`, qui l'explique en détail.

## `reference/` — ce que le code émettait

Produit par le script Node d'origine, et par un script jetable équivalent pour les enveloppes, avec un générateur d'UUID déterministe (`1a2b3c4d-0000-4000-8000-<compteur>`) et une horloge figée au `2026-08-06T10:00:00.000Z`. Les constructeurs Rails doivent rendre **ces documents**, en recevant les mêmes valeurs figées.

| Répertoire | Contenu |
| --- | --- |
| `reference/messages/` | Les cinq messages RegRep (`requete`, `reponse`, `erreur`, `erreurRequeteInvalide`, `erreurCapaciteNonSupportee`), chacun en corps (`.xml`) et en entête ebMS (`.entete.xml`). Ce sont eux que `scripts/validate_schematron.sh` confronte aux règles des TDD. |
| `reference/soap/` | Les enveloppes soumises au plugin WS : `<message>.soumission.xml` pour les cinq messages, plus `listeMessagesEnAttente` (avec et sans filtre de conversation) et `recuperationMessage`. Comparées par `spec/builders/submit_envelope_reference_spec.rb` — ce que la passerelle reçoit est l'enveloppe, pas le corps seul. |

> [!IMPORTANT]
> Ces fichiers portent deux bizarreries du code d'origine, que la version Rails ne reproduit **pas** : le contenu base64 d'une pièce jointe y est entouré de parenthèses littérales (`<value>(…)</value>`), ce qui n'est pas du base64 et ne passait que parce qu'un décodeur MIME ignore les caractères hors alphabet ; et les titres d'un type de justificatif au-delà du premier y sont joints par une virgule. Le test de bout en bout, qui traverse une vraie passerelle, juge cet écart et le valide.

## `incoming/reel/` — ce que la passerelle envoie vraiment

**C'est le modèle sur lequel écrire les XPath.** Ces sept enveloppes ont été capturées sur un vrai Domibus 5.2.1, pendant le dernier passage du test de bout en bout Node, en interceptant les réponses du plugin WS. Elles sont bien formées, et elles seules disent la vérité sur les espaces de noms.

| Fichier | Contenu |
| --- | --- |
| `requete.xml` | `ExecuteQueryRequest` entrante, démarche `00` |
| `requete.demarcheInconnue.xml` | idem, démarche `T3` |
| `reponseAvecPieceJointe.xml` | `ExecuteQueryResponse` portant le PDF |
| `erreurObjetIntrouvable.xml` | `ExceptionResponse`, `EDM:ERR:0004` |
| `listeMessagesEnAttente.xml`, `listeMessagesEnAttente.vide.xml` | `listPendingMessagesResponse`, avec et sans message |
| `soumissionMessage.xml` | `submitResponse` |

> [!IMPORTANT]
> **Les préfixes d'espace de noms changent d'une réponse à l'autre** : le même espace de noms ebMS est `ns3:` dans une réponse et `ns5:` dans une autre, selon ce que le générateur de Domibus a produit. Un analyseur qui reconnaît `ns5:Action` fonctionne par accident et cassera au premier message qui arrive autrement. Les XPath doivent lier les **URI**, jamais les préfixes.
>
> À noter aussi : le `submitResponse` réel porte un `messageEntityID` que les enveloppes écrites à la main ignoraient.

## `incoming/` — ce que les tests fabriquaient

Produit par les constructeurs de `test/constructeurs/`. C'est un corpus de **non-régression** qui couvre des cas que la passerelle n'a pas produits ici — une requête amputée d'un slot, une erreur `EDM:ERR:0002` avec sa prévisualisation, un attribut `code` manquant. Ce n'est pas une référence de fidélité : ces enveloppes sont écrites à la main, non observées sur le fil.

| Fichier | Ce qu'il éprouve |
| --- | --- |
| `requete.xml` | Une `ExecuteQueryRequest` complète, démarche `00` |
| `requete.demarcheInconnue.xml` | Démarche `T3`, à laquelle la réponse est `EDM:ERR:0004` |
| `requete.sansProcedure.xml`, `requete.sansRequeteur.xml` | Les incomplétudes qui valent `EDM:ERR:0003` |
| `reponseAvecPieceJointe.xml` | Une `ExecuteQueryResponse` portant un justificatif |
| `erreurAutorisationRequise.xml` | `EDM:ERR:0002` avec son slot `PreviewLocation` et sa sévérité `PreviewRequired` |
| `erreurObjetIntrouvable.xml` | `EDM:ERR:0004` |
| `erreurSansCode.xml` | L'attribut `code` omis, que `R-EDM-ERR-C026` impose pourtant : la lecture doit s'en passer plutôt que buter dessus |

> [!NOTE]
> **Quatre de ces huit fichiers n'étaient pas du XML bien formé, et ont été réparés** au moment de porter les analyseurs. Trois défauts distincts, tous invisibles pour `fast-xml-parser` qui effaçait les préfixes avant de lire :
>
> - l'entête employait `ns5:` **et** `eb:` pour le même espace de noms ebMS, sans en déclarer aucun ;
> - le corps encodé employait `xsi:type` sans déclarer `xsi` ;
> - la déclaration `<?xml …?>` des requêtes était précédée d'un saut de ligne, ce qu'un analyseur strict refuse.
>
> La réparation ne change que les déclarations d'espaces de noms et cette ligne blanche : le contenu, lui, est celui que les constructeurs produisaient. Ces fichiers restent un corpus de non-régression, pas un modèle — c'est `incoming/reel/` qui tient ce rôle.

## `common_services/` — ce que les annuaires centraux répondent vraiment

Six réponses capturées sur l'**environnement d'acceptation** des Common Services, qui est public, chacune accompagnée d'un fichier `.headers` portant ses deux en-têtes de signature (`digest` et `oots-response-sig`). Elles font foi au même titre qu'`incoming/reel/` : c'est sur elles que se lisent la forme réelle des réponses RegRep des annuaires et le mécanisme de signature du chapitre 3.6.2.

| Fichier | Contenu |
| --- | --- |
| `eb_requirements_fr` | Evidence Broker, exigences de la démarche `00` pour la France |
| `eb_requirements_vides` | la même requête pour `T3`, à laquelle la France ne répond rien : `EB:ERR:0001` |
| `eb_evidence_types_fr`, `eb_evidence_types_fi` | Evidence Broker, types de justificatif satisfaisant l'exigence de test, pour la France et pour la Finlande |
| `dsd_data_services_fi` | Data Service Directory, le service finlandais qui déclare `oots-edm:v2.0` |
| `dsd_aucun_service_fr` | la même requête pour la France, qui n'a aucun service inscrit : `DSD:ERR:0001` |

> [!IMPORTANT]
> **Ne pas retoucher ces fichiers.** Leur signature couvre les octets du corps : changer un caractère la casse, et `spec/clients/common_services_signature_spec.rb` — qui vérifie la vraie signature de la Commission — vire au rouge. Un cas de figure qui demande un corps différent se fabrique dans la spec, à partir de la fixture, jamais en éditant la fixture.
