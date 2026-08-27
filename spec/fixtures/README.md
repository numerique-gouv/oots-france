# Fixtures de référence

Ces fichiers ont été produits par l'application **Node**, juste avant sa suppression, et constituent le cahier des charges exécutable de la réécriture en Rails. Ils ne sont pas des exemples : ce sont des attendus, que la suite compare.

> [!NOTE]
> La comparaison porte sur le **document**, non sur les octets : ordre, noms, espaces de noms, attributs et texte, en ignorant les blancs entre éléments et en normalisant les UUID par ordre d'apparition. Les octets de référence portent en effet des artefacts de l'interpolation qui les a produits, qu'aucune spécification ne demande. Les charges encodées en base64 sont décodées avant d'être comparées, faute de quoi la comparaison porterait sur leur indentation. Voir `spec/support/xml_matchers.rb`, qui l'explique en détail.

## `reference/` — ce que le code émettait

Produit par le script Node d'origine, et par un script jetable équivalent pour les enveloppes, avec un générateur d'UUID déterministe (`1a2b3c4d-0000-4000-8000-<compteur>`) et une horloge figée au `2026-08-06T10:00:00.000Z`. Les constructeurs Rails doivent rendre **ces documents**, en recevant les mêmes valeurs figées.

| Répertoire | Contenu |
| --- | --- |
| `reference/messages/` | Les sept messages RegRep (`requete`, `reponse`, `reponseDifferee`, `erreur`, `erreurRequeteInvalide`, `erreurCapaciteNonSupportee`, `erreurExpiration`), chacun en corps (`.xml`) et en entête ebMS (`.entete.xml`). Ce sont les documents que les constructeurs Rails doivent rendre ; `scripts/validate_schematron.sh`, lui, refait rendre ses spécimens par le code (`rake oots:messages`) avant de les confronter aux règles des TDD. |
| `reference/soap/` | Les enveloppes soumises au plugin WS : `<message>.soumission.xml` pour les cinq premiers d'entre eux — l'enveloppe ne varie pas d'un code d'erreur à l'autre, et `erreurExpiration` n'en a donc pas —, plus `listeMessagesEnAttente` (avec et sans filtre de conversation) et `recuperationMessage`. Comparées par `spec/builders/submit_envelope_reference_spec.rb` — ce que la passerelle reçoit est l'enveloppe, pas le corps seul. |

> [!NOTE]
> **Deux spécimens n'ont pas de jumeau ici**, pour la même raison : Node ne les a jamais produits, et un attendu que le code du dépôt aurait lui-même écrit ne prouverait rien de plus que son gabarit dit déjà. `erreurSansIdentifiantDeRequete`, la réponse d'erreur dépourvue de `requestId` que `R-EDM-ERR-C025` n'autorise que sous `rs:InvalidRequestExceptionType`, jugée par `scripts/validate_schematron.sh` et `spec/builders/error_response_builder_spec.rb` ; et `requetePersonneMorale`, la requête dont le sujet est une personne morale — `R-EDM-REQ-S016` n'admettant qu'un sujet par requête, elle ne peut pas être le même document que `requete` —, jugée par `scripts/validate_schematron.sh` et par le bloc `a request about a legal person` de `spec/builders/evidence_request_builder_spec.rb`, `spec/builders/legal_person_builder_spec.rb` n'exerçant que le fragment.

> [!IMPORTANT]
> **La requête, elle, a été refaite depuis.** `messages/requete.xml` et `soap/requete.soumission.xml` ne sont plus ce que Node émettait : le bouchon 7 y écrivait une exigence et un identifiant de service en dur, là où le dépôt écrit désormais ce que les annuaires publient. Ces deux fichiers disent donc ce que les TDD exigent, et non ce qu'un code antérieur produisait ; les règles Schematron du chapitre 4.5.1 en sont le juge. Le reste du corpus garde sa provenance, sous la réserve ci-dessous.

> [!IMPORTANT]
> **L'identité du point d'accès français, elle, suit la configuration et non l'histoire.** Les entêtes ebMS et les enveloppes de soumission disent `AP_FR_01` de type `urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR`, là où Node émettait `…unregistered:oots` — et, sur `erreurExpiration`, `blue_gw`. C'est celle que déclare [le PMode](../../docs/domibus_context.md#le-pmode-dexemple) : un corpus qui garderait l'ancienne apprendrait un identifiant qui n'existe nulle part. `AP_DE_01`, correspondant fictif, garde la sienne — le type d'une partie est choisi par l'État membre qui la déclare.

> [!IMPORTANT]
> Ces fichiers portent deux bizarreries du code d'origine, que la version Rails ne reproduit **pas** : le contenu base64 d'une pièce jointe y est entouré de parenthèses littérales (`<value>(…)</value>`), ce qui n'est pas du base64 et ne passait que parce qu'un décodeur MIME ignore les caractères hors alphabet ; et les titres d'un type de justificatif au-delà du premier y sont joints par une virgule. Le test de bout en bout, qui traverse une vraie passerelle, juge cet écart et le valide.

## `incoming/reel/` — ce que la passerelle envoie vraiment

**C'est le modèle sur lequel écrire les XPath.** Ces sept enveloppes ont été capturées sur un vrai Domibus 5.2.1, pendant le dernier passage du test de bout en bout Node, en interceptant les réponses du plugin WS. Elles sont bien formées, et elles seules disent la vérité sur les espaces de noms.

Elles précèdent le renommage de la partie et disent donc encore `blue_gw` : c'est ce que la passerelle a émis à l'instant de la capture, et le réécrire ferait mentir une observation. Aucun test n'y lit l'identité de la passerelle — ces enveloppes servent aux XPath et aux préfixes d'espaces de noms.

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
| `reponseDifferee.xml` | Une `ExecuteQueryResponse` de statut `Unavailable` : elle annonce une date et **ne porte aucune charge PDF**, ce qu'aucune altération de `reponseAvecPieceJointe` ne sait produire |
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

Sept réponses capturées sur l'**environnement d'acceptation** des Common Services, qui est public, chacune accompagnée d'un fichier `.headers` portant ses deux en-têtes de signature (`digest` et `oots-response-sig`). Elles font foi au même titre qu'`incoming/reel/` : c'est sur elles que se lisent la forme réelle des réponses RegRep des annuaires et le mécanisme de signature du chapitre 3.6.2.

| Fichier | Contenu |
| --- | --- |
| `eb_requirements_fr` | Evidence Broker, exigences de la démarche `00` pour la France |
| `eb_requirements_catalogue` | la même requête **sans aucun paramètre**, tous facultatifs : le catalogue entier, 53 exigences et 687 déclarations de démarche sur 27 pays. C'est ce que lit `Directories::Catalogue` |
| `eb_requirements_vides` | la même requête pour `T3`, à laquelle la France ne répond rien : `EB:ERR:0001` |
| `eb_evidence_types_fr`, `eb_evidence_types_fi` | Evidence Broker, types de justificatif satisfaisant l'exigence de test, pour la France et pour la Finlande |
| `dsd_data_services_fi` | Data Service Directory, le service finlandais qui déclare `oots-edm:v2.0` |
| `dsd_aucun_service_fr` | la même requête pour la France, qui n'a aucun service inscrit : `DSD:ERR:0001` |

> [!IMPORTANT]
> **Ne pas retoucher ces fichiers.** Leur signature couvre les octets du corps : changer un caractère la casse, et `spec/clients/common_services_signature_spec.rb` — qui vérifie la vraie signature de la Commission — vire au rouge. Un cas de figure qui demande un corps différent se fabrique dans la spec, à partir de la fixture, jamais en éditant la fixture.

> [!NOTE]
> Le test de bout en bout n'emploie pas ces captures : il interroge les annuaires en direct. Les deux suites vérifient donc la même chaîne de confiance, sur des réponses obtenues autrement — figées ici, fraîches là-bas. Voir [test_e2e.md](../../docs/test_e2e.md#les-annuaires-centraux-sont-les-vrais).
