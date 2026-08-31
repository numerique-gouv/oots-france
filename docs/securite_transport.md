# Sécurité réseau et transport vers les Common Services

> Ce document confronte le [chapitre 3.7 des TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) — *Common Services Network and Transport Security*, v2.0.1 — à ce que ce dépôt fait réellement lorsqu'il interroge l'*Evidence Broker* et le *Data Service Directory*. C'est un **constat**, pas une correction : chaque exigence y reçoit un verdict, et les écarts constatés partent en tickets. Pour la vérification de la signature détachée des réponses, qui relève du [chapitre 3.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) et non de celui-ci, voir `CommonServicesSignature`.

## Le fait dont tout le reste découle : aucun client ne configure TLS

Les quatre connexions sortantes du dépôt — `CommonServicesQuery`, `CodeListClient`, `EvidenceForwarder`, `JwksFetcher` — sont des connexions [Faraday](https://lostisland.github.io/faraday/) sur l'adaptateur `net_http`, et **aucune ne passe d'option `ssl:`**. Rien non plus dans `Settings`, dans les `.env*.template` ou dans le `Dockerfile` ne touche à TLS : il n'existe ni variable d'environnement de version minimale, ni liste de suites, ni fichier `openssl.cnf` embarqué.

Le profil TLS de ce dépôt est donc, en totalité, **celui que l'image de base lui donne** : `ruby:4.0.6-slim`, dont l'OpenSSL est la 3.5.6. Ce n'est pas une figure de style — c'est la raison pour laquelle la plupart des verdicts ci-dessous se lisent « satisfaite par défaut, et non par une décision de ce dépôt ».

### Comment le constat a été établi

Les listes exactes ne se déduisent pas d'une documentation : elles se lisent dans le `ClientHello` que le client émet. Celui-ci a été capturé en faisant dialoguer un contexte OpenSSL Ruby par défaut — celui que `Net::HTTP` construit, `DEFAULT_PARAMS` appliqué — avec un `s_server -trace`, dans l'image épinglée elle-même :

```sh
docker run --rm ruby:4.0.6-slim sh -c '
cd /tmp
openssl req -x509 -newkey rsa:3072 -keyout k.pem -out c.pem -days 2 -nodes -subj "/CN=localhost" >/dev/null 2>&1
(openssl s_server -cert c.pem -key k.pem -accept 4433 -trace -www > trace.txt 2>&1 &)
sleep 2
ruby -ropenssl -rsocket -e "
  ctx = OpenSSL::SSL::SSLContext.new
  ctx.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
  s = OpenSSL::SSL::SSLSocket.new(TCPSocket.new(\"127.0.0.1\", 4433), ctx)
  s.connect; puts s.ssl_version; s.close"
sed -n "/cipher_suites (len=/,/compression_methods/p;/extension_type=supported_/,+12p" trace.txt'
```

Une poignée de main réelle contre l'instance d'acceptation confirme le résultat de bout en bout : `openssl s_client -connect query.cs.acc.oots.tech.ec.europa.eu:443` négocie **TLSv1.3 / TLS_AES_128_GCM_SHA256**, certificat vérifié (`Verify return code: 0 (ok)`), signature du pair `ecdsa_secp384r1_sha384`.

> [!IMPORTANT]
> Ce constat vaut pour l'image `ruby:4.0.6-slim` au 31 août 2026. Comme rien dans le dépôt n'épingle le profil, **une montée de version de l'image le déplace sans que rien ne le signale** — ni un test, ni la CI. C'est le sujet du ticket « épingler le plancher TLS » proposé plus bas.

## Le tableau des verdicts

| Exigence | Force | Ce que fait la configuration réelle | Verdict |
| --- | --- | --- | --- |
| §3.1 — « *It MUST be possible to configure the accepted TLS version(s) in the TLS implementation* » | MUST | OpenSSL 3.5.6 l'admet — `SSLContext#min_version=`, ou `MinProtocol` dans `openssl.cnf`. L'application n'use de ni l'un ni l'autre : la possibilité existe, elle n'est pas exercée. | **satisfaite** |
| §3.1 — « *It MUST be possible to configure accepted TLS cipher suites in the TLS implementation* » | MUST | Idem : `SSLContext#ciphers=` et `ciphersuites=` existent, Faraday sait les transmettre par `ssl:`, aucune connexion ne s'en sert. | **satisfaite** |
| §3.2 — « *MUST NOT use SSL 3.0, TLS 1.0 and 1.1* » | MUST NOT | Le `ClientHello` n'annonce que TLS 1.3 (772) et TLS 1.2 (771) dans son extension `supported_versions`. Une poignée de main avec un serveur limité à TLS 1.0 ou 1.1 échoue. Rien dans le dépôt ne le garantit : c'est le défaut d'OpenSSL 3.5. | **satisfaite** |
| §3.2 — « *MUST therefore at a minimum support TLS 1.2* » | MUST | TLS 1.2 est annoncé et négocié avec succès contre un serveur qui n'offre que lui. | **satisfaite** |
| §3.2 — « *SHOULD support the use of TLS 1.3* » | SHOULD | TLS 1.3 est annoncé en premier et effectivement négocié avec `query.cs.acc.oots.tech.ec.europa.eu`. | **satisfaite** |
| §3.3 — suites TLS 1.3 : `TLS_AES_128_GCM_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_AES_128_CCM_SHA256`, plus `TLS_CHACHA20_POLY1305_SHA256` en option | SHOULD | Trois des quatre sont offertes (`0x1301`, `0x1302`, `0x1303`). **`TLS_AES_128_CCM_SHA256` est absente** : OpenSSL ne place aucune suite CCM dans sa liste par défaut. | **écart** |
| §3.3 — suites TLS 1.2 à confidentialité persistante énumérées par le chapitre | SHOULD | Quatre des six sont offertes : `ECDHE_ECDSA_AES{128,256}_GCM_SHA{256,384}` et `ECDHE_RSA_AES{128,256}_GCM_SHA{256,384}`. **`TLS_ECDHE_ECDSA_WITH_AES_256_CCM` et `…_AES_128_CCM` sont absentes**, et c'est là tout l'écart. Le client offre par ailleurs dix suites que le chapitre n'énumère pas, ce qui ne lui en est pas un : le §3.3 le permet expressément — « *Further cipher suites may be used when following specific regulations.* » | **écart** |
| §3.4 — courbes : `secp256r1`, `secp384r1`, `secp521r1`, `x25519`, `x448` | SHOULD | Les cinq sont dans `supported_groups`, précédées de `X25519MLKEM768` — un groupe hybride post-quantique que le chapitre ne connaît pas et n'interdit pas. | **satisfaite** |
| §3.4 — « *at least ffdhe3072 should be used* » | SHOULD | `ffdhe3072` est offert, mais **`ffdhe2048` l'est aussi et le précède** dans la liste : un serveur qui suit la préférence du client obtient 2048 bits, en deçà du plancher recommandé. | **écart** |
| §3.5 — profil de certificat (`digitalSignature`, `serverAuth` obligatoires, `clientAuth` interdit, `cA = false`, `subjectAltName`, validité ≤ 398 jours…) | MUST | Le titre de la section est « *Certificate Profile for TLS Server Certificates* » : ces exigences pèsent sur les certificats **serveur** des Common Services, que ce dépôt ne délivre pas. | **sans objet** |
| §3.5 + §4 — corollaire : `clientAuth` interdit, donc **aucun TLS mutuel** vers les Common Services | MUST NOT | Aucune connexion ne fixe `client_cert` ni `client_key`, et `Net::HTTP#cert` vaut `nil` par défaut : le client ne présente aucun certificat. La vérification du certificat serveur, elle, reste active (`VERIFY_PEER` et `verify_hostname` viennent de `DEFAULT_PARAMS`). | **satisfaite** |
| §4 — « *Access to the OOTS common services by clients using the REST interface shall be public* » | SHALL | Exigence adressée aux *providers of OOTS common services*, pas au client. Ce dépôt n'en délivre aucun. | **sans objet** |
| §4 — « *Clients should limit unnecessary access* » et « *proxy caching* » | SHOULD | Tout est mis en cache pour `DUREE_CACHE_SERVICES_COMMUNS` (3 600 s en acceptation) : la résolution NAPTR dans `CommonServicesInstance`, les réponses des annuaires dans `CommonServicesQuery`, les listes de codes dans `CodeListClient` ; les clés publiques des requêtants le sont cinq minutes dans `JwksFetcher`. Les reprises sont bornées (`retry, max: 2`, `backoff_factor: 2`) et le délai d'attente à `DELAI_MAX_SERVICES_COMMUNS`, soit 10 s. | **satisfaite** |
| §4 — « *rate limiting and/or other technical measures may be applied* » | MAY | Faculté ouverte aux *common service operators*. Côté client, rien à appliquer. | **sans objet** |
| §2 — « *It is RECOMMENDED that all DNS record lookups in OOTS are secured using DNSSEC* » | RECOMMENDED | `CommonServicesInstance#records` interroge par `Resolv::DNS`, qui **ne connaît pas DNSSEC** : le mot n'apparaît pas dans `resolv.rb`, la bibliothèque ne pose pas le bit DO et ne lit pas le bit AD. La validation, si elle a lieu, a lieu dans le résolveur du système — que ce dépôt ne fixe pas. | **non établi** |

**Récapitulatif : 8 satisfaites, 3 écarts, 1 non établie, 3 sans objet.**

## Ce que valent les trois écarts

Les trois portent sur des exigences en *should*, et aucun ne rend un échange impossible aujourd'hui : l'instance d'acceptation négocie TLS 1.3 avec une suite que le chapitre recommande, et le choix appartient de toute façon au serveur, qui refuserait ce qu'il ne veut pas. Deux d'entre eux tiennent à ce que le client **n'offre pas** ce que le chapitre lui demande d'offrir — les trois suites CCM —, et le troisième à ce qu'il offre `ffdhe2048` là où le §3.4 pose un plancher sur ce qui est employé : un correspondant mal configuré peut alors emmener l'échange sous ce plancher. Les corriger revient à ajouter à la liste offerte les suites CCM que le chapitre y met, et à retirer des groupes celui qui passe dessous.

Les trois se réparent au même endroit — l'option `ssl:` des connexions Faraday, ou une valeur de `SSLContext` partagée — ce qui exercerait du même coup les deux exigences de configurabilité du §3.1, aujourd'hui satisfaites par OpenSSL et par rien d'autre.

> [!WARNING]
> `config.cache_store` n'est pas déclaré en production (`config/environments/production.rb` le laisse commenté), donc Rails retombe sur son `:file_store` de `tmp/cache`. Le cache existe et répond au *should* du §4, mais **il n'est partagé entre `web` et `worker` que par le montage du volume de la pile locale** : un déploiement où les deux processus ne partagent pas ce répertoire double les appels aux annuaires sans que rien ne le dise.

## Ce que ce document ne couvre pas

- **La signature détachée des réponses** (`oots-response-sig`), qui relève du [chapitre 3.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) : elle est vérifiée par `CommonServicesSignature` contre le magasin de `CERTIFICATS_SERVICES_COMMUNS`. Le chapitre 3.7 place délibérément cette garantie **au-dessus** du transport, parce que le [chapitre 3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) invite à intercaler un cache mandataire qui terminerait TLS.
- **Le transport AS4 vers la passerelle**, qui suit le profil eDelivery du [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) et la configuration de Domibus, non ce chapitre-ci — voir [domibus_context.md](domibus_context.md).
- **Le TLS que les fournisseurs de service français rencontrent en appelant cette application** : c'est un mandataire inverse qui le termine (`config.assume_ssl` et `config.force_ssl` en production), et le chapitre 3.7 ne régit que l'accès *aux* Common Services.
