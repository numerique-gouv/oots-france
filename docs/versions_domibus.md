# Versions de Domibus et perspectives de mise à jour

> Ce document explique **quelle version de Domibus ce dépôt utilise, ce qu'elle
> coûte, et ce qu'apporterait une version plus récente**. Il ne redit pas ce qui
> est écrit ailleurs :
>
> | Pour… | Voir |
> | --- | --- |
> | ce qu'est Domibus, le PMode d'exemple, la façon dont l'application s'en sert | [domibus_context.md](domibus_context.md) |
> | installer et configurer la passerelle pas à pas | [README](../README.md) |
> | le scénario de bout en bout et la configuration automatisée | [test_e2e.md](test_e2e.md) |
> | le versionnement des **spécifications OOTS**, sans rapport avec celui de Domibus | [versions_tdd.md](versions_tdd.md) |

## La version utilisée ici

`docker-compose.yml` fige **Domibus 5.0.4**, construit en février 2023. La
version courante est
[5.2.1.1](https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/Domibus)
(juillet 2026) : le dépôt a donc trois années de retard, et deux versions
mineures.

> [!NOTE]
> La version de Domibus et celle des TDD sont **indépendantes** : Domibus
> transporte, il ne connaît pas le modèle de données OOTS. Migrer l'un
> n'impose rien sur l'autre — pour les TDD, voir
> [versions_tdd.md](versions_tdd.md).

## Ce que 5.0.4 coûte aujourd'hui

Les contournements correspondants vivent dans `scripts/configureDomibus.sh` et
`scripts/ci/` :

| Constat | Ce qu'il impose |
| --- | --- |
| Le keystore ne se téléverse pas ; seule sa relecture depuis le fichier est exposée (`POST rest/keystore/resets`) | Déposer le fichier dans le répertoire monté, puis demander sa relecture — en deux temps, là où le truststore se téléverse directement |
| L'API d'administration n'est pas documentée publiquement pour cette version | Les routes ont dû être retrouvées en sondant la passerelle, puis en lisant le *bundle* Angular de la console pour y trouver `reloadKeyStore()` |
| Aucune route de santé | La disponibilité se sonde sur `rest/application/name`, qui renvoie la chaîne `"Domibus"` — il se trouve qu'elle ne répond qu'une fois la webapp déployée |
| Les réponses sont préfixées par `)]}',` | Ce préfixe doit sauter avant tout parsage |
| Les certificats de démonstration livrés avec l'image ont expiré le 1er décembre 2025 | Ils doivent être régénérés, sans quoi la passerelle refuse d'émettre (`EBMS_0004`) |
| L'image écrase le répertoire de configuration monté à son premier démarrage | Les certificats ne peuvent être remplacés qu'**après** ce démarrage |
| Domibus absorbe `gateway_truststore.jks` au démarrage et retire le fichier | Le magasin doit être généré ailleurs pour rester téléversable |

## Ce qu'apporterait une version plus récente

| Version | Apport | Ce que cela retirerait ici |
| --- | --- | --- |
| [5.1](https://ec.europa.eu/digital-building-blocks/wikis/display/DIGITAL/Domibus+v5.1+Admin+Console+Help) | Téléversement du keystore, du truststore et du TLS truststore depuis la console, mot de passe compris ; le bouton de relecture depuis le disque subsiste. Un magasin identique à celui en place n'est pas remplacé | Le détour par le fichier pour le keystore : les deux magasins se poseraient par la même API, et le script y gagnerait sa symétrie |
| [5.1.9](https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/Domibus+-+v5.1.9) | Le mot de passe du keystore peut différer de celui des clés privées | Une contrainte en moins sur `scripts/genereCertificats.sh`, qui impose aujourd'hui le même mot de passe aux deux |
| [5.2.1](https://ec.europa.eu/digital-building-blocks/sites/display/DIGITAL/Domibus+-+v5.2.1) | Un *Domibus REST Plugin* 1.0, à interface **OpenAPI** documentée (variantes Jakarta EE 10 seulement) | Le sondage à l'aveugle : les routes seraient décrites, et le plugin REST pourrait à terme remplacer les enveloppes SOAP du WS plugin construites dans `src/domibus/requetes.js` |

Une image plus récente livrerait par ailleurs des certificats de démonstration
non expirés — mais les régénérer reste préférable : ceux de l'image sont publics
et partagés par toutes les installations.

## Ce qu'il faudrait vérifier avant de migrer

> [!IMPORTANT]
> Le test de bout en bout est le garde-fou de cette migration : il exerce la
> chaîne réelle, là où la suite unitaire simule le transport. Le jouer contre la
> nouvelle version dira en une exécution si le contrat tient — voir
> [test_e2e.md](test_e2e.md).

- **Le WS plugin**, dont dépend tout `src/domibus/` : les opérations
  `submitMessage`, `listPendingMessages` et `retrieveMessage` sont-elles
  inchangées, et leur namespace `http://eu.domibus.wsplugin/` avec ?
- **Le schéma du PMode** : `exemples/configuration_PMode_Domibus.xml` est écrit
  pour 5.0.4 et refusé s'il ne valide plus.
- **Le serveur d'applications** : 5.2 tourne sur Tomcat 10.1, donc sur Jakarta
  EE 10 — l'image et les propriétés changent en conséquence.
- **Les routes d'administration** utilisées par `scripts/configureDomibus.sh` :
  elles ne sont pas contractuelles, rien ne garantit leur stabilité d'une
  version à l'autre.
