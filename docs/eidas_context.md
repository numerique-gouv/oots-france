# Contexte eIDAS — l'identification de l'usager, et FranceConnect+ qui la porte

> Ce document explique **d'où vient l'identité de l'usager dans un échange OOTS, et par quoi la France l'obtient** : le nœud eIDAS français, que l'on n'atteint que par FranceConnect+. Il ne redit pas ce qui est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | le contexte métier OOTS, le déroulé d'un échange | [oots_context.md](oots_context.md) |
> | un terme du domaine (bénéficiaire, jeu minimal de données, niveau de garantie…) | [glossaire.md](glossaire.md) |
> | ce qui manque au dépôt sur le chapitre 2 des TDD, et le projet Linear qui le porte | [reste_à_faire.md](reste_à_faire.md) |
> | le texte des TDD sur l'identité : les attributs, le rapprochement, la représentation | [chapitre 2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924), cartographié dans [carte_des_tdd.md](carte_des_tdd.md#chapitre-2--les-sous-chapitres-qui-servent) |
> | la documentation de FranceConnect+ elle-même | [docs.partenaires.franceconnect.gouv.fr](https://docs.partenaires.franceconnect.gouv.fr/fs/) |

## Ce que les TDD attendent, et ce qu'ils laissent à l'État membre

OOTS n'authentifie personne. Le [chapitre 1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932933) place l'authentification **avant** l'échange, chez le portail de procédure : l'usager s'identifie avec le moyen d'identification électronique de son pays, notifié au titre du [règlement eIDAS](https://eur-lex.europa.eu/legal-content/FR/TXT/HTML/?uri=CELEX:32014R0910), à travers le nœud eIDAS du pays où se fait la démarche et « un service national d'authentification » que le texte ne nomme pas. Ce qui en sort, et que le requêteur met dans la requête, est le [jeu minimal de données](glossaire.md#lusager-et-son-identité) du [chapitre 2.1](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932924), marqué du [niveau de garantie](glossaire.md#lusager-et-son-identité) du moyen employé — le [chapitre 2.2](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932937) dit que les attributs issus d'une assertion eIDAS portent celui de ce moyen, et rien d'autre. Aucun minimum n'est fixé : c'est le fournisseur qui décide, par l'`AuthenticationLevelOfAssurance` qu'il publie au DSD, ce qu'il exige.

Le portail, le service national d'authentification et le nœud sont donc à choisir par l'État membre. En France, les trois sont tenus par la DINUM sous un seul nom : **FranceConnect+**.

## Le nœud eIDAS français s'atteint par FranceConnect+, pas par FranceConnect

FranceConnect et FranceConnect+ sont deux plateformes distinctes, avec le même protocole et des fournisseurs d'identité différents ([différences](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-pilotage/fs-pilotage-differences-fc-fc-plus/)) :

| | FranceConnect | FranceConnect+ |
| --- | --- | --- |
| Niveaux de garantie | faible seulement | substantiel et élevé |
| Fournisseurs d'identité | impots.gouv, Ameli, MSA, La Poste, France Identité | La Poste (substantiel), France Identité (élevé) |
| Jetons | signés | signés **et chiffrés** |
| Usagers d'un autre État membre | non | **oui, sur demande** |

Le [nœud d'interopérabilité eIDAS](https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/projet-fonctionnement-noeud-eidas/) est opéré par la DINUM et n'est joignable qu'à travers FranceConnect+ ; son accès « n'est pas activé par défaut » et se demande à l'équipe FranceConnect. Il ne donne que les niveaux **substantiel** et **élevé**, ce qui découle des schémas notifiés que les autres États membres exposent, pas d'un choix français. Le [parcours de l'usager](https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/projet-eidas-cinematique-usager/) est celui du chapitre 1 : un bouton dédié à côté de ceux de FranceConnect+, le choix du pays, l'authentification chez le nœud de ce pays, un écran de confirmation des données transmises, le retour au service.

> [!NOTE]
> La [page du bouton d'interopérabilité européenne](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-integration/integration-bouton-eidas/) annonce ses règles d'intégration comme « bientôt publiées » ; en attendant, seul le paramètre d'appel ci-dessous est documenté.

## Ce que FranceConnect+ demande d'un fournisseur de service

Devenir fournisseur de service passe par deux guichets successifs ([étapes](https://docs.partenaires.franceconnect.gouv.fr/fs/devenir-fs/pilotage-etapes/)) :

1. **Une habilitation**, sur [Datapass](https://docs.partenaires.franceconnect.gouv.fr/fs/devenir-fs/projet-datapass/). Une administration y est éligible de droit ([conditions d'éligibilité](https://docs.partenaires.franceconnect.gouv.fr/fs/devenir-fs/pilotage-eligibilite/)) ; le dossier décrit le service, les données demandées, leur durée de conservation, le cadre juridique et le niveau visé (FranceConnect+ pour eIDAS 2 ou 3). Réponse « en quelques jours dans la majorité des cas ».
2. **La création du fournisseur de service** dans l'environnement voulu, par le [formulaire](https://demarche.numerique.gouv.fr/commencer/demande-creation-fs-fc) de demarche.numerique.gouv.fr ([bac à sable FranceConnect+](https://docs.partenaires.franceconnect.gouv.fr/fs/devenir-fs/projet-bac-a-sable-fcplus/)). Toute modification ultérieure passe par un [second formulaire](https://demarche.numerique.gouv.fr/commencer/demande-modification-fs-fc).

La seconde demande déclare des **adresses**, et c'est là que tout se joue pour ce dépôt. Un fournisseur de service FranceConnect+ fournit : l'URL du service ; ses URLs de redirection, de connexion et de déconnexion ; ses adresses IP sortantes ; son algorithme de signature ; et, propre à FranceConnect+, **l'URL où il publie ses clés publiques de chiffrement** au format JWK, avec l'algorithme de chiffrement choisi. Une instance de fournisseur de service ne porte qu'un domaine et un port : « il n'est pas permis d'enrôler plusieurs environnements sous une même instance ».

> [!IMPORTANT]
> **Sans déploiement joignable, pas de bac à sable FranceConnect+.** Les URLs déclarées doivent répondre : FranceConnect+ vient y chercher les clés de chiffrement avant d'émettre un jeton, et y renvoie l'usager après l'authentification. Une pile locale ne suffit pas. C'est la même dépendance que celle des annuaires centraux, où la France reste déclarée sous le point d'accès de test faute de serveur à nommer.

### Les adresses que ce dépôt déclarera

Trois chemins existent dès aujourd'hui, servis sans session par `FranceConnectController`, pour que la demande puisse se déposer le jour où un serveur les porte. `<domaine>` est celui de ce déploiement, unique : « il n'est pas permis d'enrôler plusieurs environnements sous une même instance de fournisseur de service ».

| Ce que le formulaire demande | Chemin |
| --- | --- |
| Client keys url | `<domaine>/demo/franceconnect/cles_publiques` |
| URL de redirection de connexion | `<domaine>/demo/franceconnect/retour_connexion` |
| URL de redirection de déconnexion | `<domaine>/demo/franceconnect/retour_deconnexion` |

Ils sont sous `/demo`, du nom que la console donne à la démarche de démonstration, et **hors de `/admin`** que la connexion de l'exploitant ferme : FranceConnect+ lit la première en client anonyme, et ramène l'usager sur les deux autres avant que cette application sache qui il est. La clé publiée est **propre à la démarche** — `CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64`, distincte de celle du jeton du bénéficiaire que sert `/auth/cles_publiques` : deux correspondants, deux interfaces. Son `alg` ne peut valoir que `RSA-OAEP-256` ou `ECDH-ES`, et le démarrage refuse toute autre valeur plutôt que de laisser FranceConnect+ la refuser à sa place.

> [!NOTE]
> **Ces chemins ne sont pas encore déclarés, donc encore libres.** Une fois la demande déposée, toute modification passe par le [second formulaire](https://demarche.numerique.gouv.fr/commencer/demande-modification-fs-fc) : les changer coûtera alors un aller-retour avec FranceConnect+.

Ce que les deux pages de retour affichent aujourd'hui — un titre, une phrase, un lien vers la démarche — n'a d'autre objet que de répondre `200`, ce que FranceConnect+ exige d'une adresse déclarée. Ce qui s'y passera vraiment vient avec [OOTS-179](https://linear.app/pole-api/issue/OOTS-179).

> [!IMPORTANT]
> **Ce sont les seules pages de ce dépôt qu'un usager final atteint**, et donc un écart nommé avec la [règle d'audience](../CLAUDE.md#this-repository-implements-the-tdd-it-does-not-invent), qui n'excepte que la console d'exploitation. Il est assumé pour ce que la démonstration est — un portail de démarche joué, dont le [projet Linear](https://linear.app/pole-api/project/oots-france-le-portail-de-demonstration-484068da336c) porte les décisions — et il n'autorise rien au-delà : aucune autre page ne se met devant un usager sans y revenir.

## Le protocole : OpenID Connect, chiffré

FranceConnect+ est un fournisseur [OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html) qui n'implémente que l'*authorization code flow* ([implémentation](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-oidc-fc-plus/)). Il publie sa configuration par *discovery* et ses clés de signature par JWKS, aux adresses de l'environnement ([endpoints](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-endpoints/)) :

| Environnement | Base | Discovery |
| --- | --- | --- |
| Intégration (bac à sable) | `https://auth.integ01.dev-franceconnect.fr/api/v2/` | [`.well-known/openid-configuration`](https://auth.integ01.dev-franceconnect.fr/api/v2/.well-known/openid-configuration) |
| Production | `https://auth.franceconnect.gouv.fr/api/v2/` | `.well-known/openid-configuration`, que la production ne sert pas à un client anonyme |

Les chemins sont `authorize`, `token`, `userinfo`, `session/end` et `jwks` sous cette base.

**Signature et chiffrement** ([détail](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-chiffrement-signature-fcplus/)). L'ID Token et la réponse UserInfo sont signés en `ES256` puis chiffrés pour le fournisseur de service, en `RSA-OAEP-256` + `A256GCM` ou `ECDH-ES` + `A256GCM` — les mêmes algorithmes que `BeneficiaryToken` impose au jeton du bénéficiaire, ce qui n'est pas un hasard. Le fournisseur de service publie ses clés de chiffrement à l'URL déclarée, et récupère « régulièrement » les clés de signature de FranceConnect+, qui tournent.

**Le niveau de garantie** ([ACR](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-eidas-acr/)). Le fournisseur de service le demande par `acr_values`, `eidas2` pour substantiel ou `eidas3` pour élevé — `eidas1` n'existe que sur FranceConnect. Le paramètre est facultatif sur FranceConnect+ ; absent, « c'est le niveau de garantie le plus élevé supporté par la plateforme qui sera pris en compte ». Le niveau **obtenu** revient dans le claim `acr` de l'ID Token, et « il est de la responsabilité du fournisseur de service de s'assurer que le niveau retourné est au moins égal ou supérieur à celui demandé ». C'est cette valeur, et non une constante, que le chapitre 2.2 attend dans la requête OOTS.

**La cinématique européenne** ([lancement](https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/technique-eidas-authorize/)). L'appel à `authorize` porte `idp_hint=eidas-bridge`, qui mène l'usager droit au choix du pays, et demande le claim `amr` en `essential`. Au retour, `amr` vaut `fc` pour une identité française et `eidas` pour celle d'un autre État membre.

**Les attributs d'un usager européen** ([données](https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/technique-eidas-identite-eu/)), selon les [scopes](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-scope-fc/) demandés :

| Claim | Obligatoire | Ce que c'est | Champ de `NaturalPerson` |
| --- | --- | --- | --- |
| `sub` | oui | l'identifiant **propre à FranceConnect** : 66 caractères hexadécimaux et la lettre `v`, « même format qu'une identité française » | aucun — voir l'avertissement |
| `given_name` | oui | prénoms d'usage, texte libre | `given_name` |
| `family_name` | oui | nom d'usage, texte libre, qui peut différer du nom de naissance | `family_name` |
| `birthdate` | oui | `AAAA-MM-JJ` ; les présumés nés ne sont pas gérés | `date_of_birth` |
| `birthplace` | non | format libre, ce n'est pas un code INSEE | — |
| `gender` | non | `male`, `female` ou `unspecified` | — |

> [!WARNING]
> **FranceConnect+ ne documente aucun claim portant l'identifiant unique eIDAS** de l'usager — le `PersonIdentifier` de la forme `DK/FR/…` que le chapitre 2.1 fait voyager dans la requête, hors [pays à identifiant supprimé](glossaire.md#lusager-et-son-identité). Le `sub` n'en tient pas lieu : c'est un pseudonyme de FranceConnect, stable par fournisseur de service, sans rapport avec l'identifiant notifié. Ni le pays d'origine ni la nationalité ne figurent parmi les claims. Ce que la France peut mettre dans `eidas_identifier` pour un usager venu par la passerelle est **à établir avec l'équipe FranceConnect**, pas à déduire de cette page.

## Le bac à sable

L'[environnement d'intégration](https://docs.partenaires.franceconnect.gouv.fr/fs/fs-integration/env-sandbox-fc-plus/) livre ses identifiants par messagerie une fois la demande acceptée. Il offre trois fournisseurs d'identité de démonstration, `FIP1-HIGH`, `FIP2-HIGH` et `FIP3-HIGH`, dont les identités de test sont publiées sur GitHub et personnalisables à la connexion. « Il est interdit d'utiliser de vraies données personnelles sur l'environnement bac à sable. »

FranceConnect ne fournit **pas de mock officiel** de FranceConnect+ pour un poste de développement. Interrogée le 2026-09-07, l'équipe renvoie à ses [sources](https://github.com/france-connect/sources), sous [AGPL-3.0](https://github.com/france-connect/sources/blob/main/LICENSE.md), qui contiennent le cœur lui-même et de quoi le faire tourner :

- [`back/instances/core-fcp-high`](https://github.com/france-connect/sources/tree/main/back/instances/core-fcp-high), l'instance FranceConnect+ du cœur, et [`docker/compose/fcp-high`](https://github.com/france-connect/sources/tree/main/docker/compose/fcp-high), la pile qui la lance avec ses dépendances (MongoDB, Redis Sentinel, un broker, un HSM simulé, un mock du RNIPP) et ses mocks — les fournisseurs d'identité `fip1-high` à `fip5-high`, dont les identités de test sont celles du bac à sable, des fournisseurs de service et de données factices.
- [`docker/compose/eidas`](https://github.com/france-connect/sources/tree/main/docker/compose/eidas), la passerelle : `eidas-bridge`, le nœud français `eidas-fr`, et un nœud et un pays factices `eidas-mock` et `eidas-be`.

Les services applicatifs tournent sur une image `nodejs` du registre privé de FranceConnect, `${FC_DOCKER_REGISTRY}/nodejs:${NODE_VERSION}-dev`, que l'équipe dit remplaçable par une image Node publique. Les nœuds eIDAS, eux, sont des images `eidas:2.6` et `eidas-mock:2.4` du même registre, construites sur le logiciel [eIDAS-Node](https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/eIDAS-Node+Integration+Package) de la Commission, sans image publique prête : le cœur FranceConnect+ et ses fournisseurs d'identité de test se montent donc à peu de frais, la passerelle demande un effort de plus. Décision du 2026-09-07 : ce dépôt n'embarque ni ne lance ce code, et continue de bouchonner FranceConnect+ par un fournisseur OpenID Connect factice écrit ici ; les sources servent de **référence de comportement** — ce que le cœur rend, refuse et vérifie se lit là quand la documentation partenaires est muette. Le projet Linear [Le portail de démonstration](https://linear.app/pole-api/project/oots-france-le-portail-de-demonstration-484068da336c) porte ce bouchon.

> [!WARNING]
> **La page du bac à sable ne dit rien de la passerelle eIDAS.** Les trois fournisseurs de démonstration sont français ; qu'un usager d'un autre État membre puisse être joué en intégration, et avec quelle identité de test, n'est écrit nulle part dans la documentation. À vérifier auprès de FranceConnect avant d'en faire dépendre une démonstration.

## Ce que ce dépôt en fait aujourd'hui

**Presque rien.** Aucune ligne d'`app/` n'appelle FranceConnect+ : ce dépôt ne fait que lui **répondre**, par les trois adresses ci-dessus, et rien encore ne les emprunte. La mention du [README](../README.md#en-production) qui motive le NGinx en frontal par « les services tiers de FranceConnect+ » décrit l'intention du déploiement, pas un appel existant. L'identité entre dans ce dépôt par le jeton du bénéficiaire qu'un fournisseur de service français chiffre pour lui — c'est [oots_context.md](oots_context.md#côté-evidence-requester-la-france-demande-un-justificatif) qui le décrit —, et le niveau de garantie qui part dans la requête est celui que ce jeton transporte : le requêteur écrit ce qu'on lui a transmis, sans valeur par défaut, faute de quoi il annoncerait un niveau que personne n'a attesté. Obtenir ce niveau de FranceConnect+, par le claim `acr`, appartient au portail.

Ce que cela dessine, et que le projet Linear [Le portail de démonstration](https://linear.app/pole-api/project/oots-france-le-portail-de-demonstration-484068da336c) porte : c'est le **portail** qui parle à FranceConnect+, pas le requêteur. Le portail authentifie l'usager, lit `acr` et les claims, et les met dans le jeton du bénéficiaire ; le requêteur les fait voyager. Le scénario retenu pour la démonstration est un étudiant danois, identifié par sa propre identité danoise à travers la passerelle eIDAS de FranceConnect+, qui demande à la France un justificatif pour une démarche **française** de bourse d'études — l'usager est étranger, mais le requêteur et le fournisseur sont tous deux la France, pour rester sur une boucle que l'on maîtrise de bout en bout. Ce que cela exige de FranceConnect+, dans l'ordre : un déploiement joignable, l'habilitation, l'accès au bac à sable, puis l'activation de la passerelle. Rien n'est encore déclaré à FranceConnect+ : la demande d'accès au bac à sable n'est pas déposée, faute du déploiement joignable qu'elle exige. Les adresses qu'elle déclarera, elles, existent — [ci-dessus](#les-adresses-que-ce-dépôt-déclarera).
