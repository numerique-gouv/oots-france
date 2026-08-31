# Sécurité réseau et transport vers les Common Services

> Ce document confronte le [chapitre 3.7 des TDD](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927) — *Common Services Network and Transport Security*, v2.0.1 — à ce que ce dépôt fait réellement lorsqu'il interroge l'*Evidence Broker* et le *Data Service Directory*. Chaque exigence y reçoit un verdict, et ce qui la satisfait est nommé. Pour la vérification de la signature détachée des réponses, qui relève du [chapitre 3.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) et non de celui-ci, voir `CommonServicesSignature`.

## Le fait dont tout le reste découle : le dépôt pose son profil, en un seul endroit

`config/initializers/tls_profile.rb` préfixe `OpenSSL::SSL::SSLContext#set_params` d'un module `TlsProfile` qui glisse quatre valeurs sous celles que l'appelant fournit : le plancher `TLS1_2_VERSION`, la liste des suites TLS 1.2 augmentée des deux CCM du §3.3, les quatre suites TLS 1.3 dont `TLS_AES_128_CCM_SHA256`, et une liste de groupes d'où `ffdhe2048` a disparu. C'est ce module, et non le défaut de l'image de base, qui décide de ce que la France offre à la poignée de main.

Les quatre connexions sortantes — `CommonServicesQuery`, `CodeListClient`, `EvidenceForwarder`, `JwksFetcher` — restent des connexions [Faraday](https://lostisland.github.io/faraday/) sur l'adaptateur `net_http` **sans option `ssl:`**, parce qu'aucune option ne saurait porter ce profil : `Faraday::SSLOptions` et `Net::HTTP::SSL_ATTRIBUTES` connaissent `ciphers` et `min_version`, ni l'un ni l'autre ne connaît `ciphersuites` ni la liste des groupes ; et `Net::HTTP#connect` construit son `SSLContext` lui-même puis passe à `set_params` un hash assemblé en variable locale, si bien qu'il n'y a ni contexte à injecter ni option à faire suivre. `set_params` est le seul appel qu'il fasse toujours, et le préfixer atteint les quatre connexions d'un coup — comme la cinquième qu'on ajoutera demain sans y penser.

> [!IMPORTANT]
> **Le profil vaut pour tout contexte TLS que le processus ouvre**, ce qui est plus large que les seules connexions aux Common Services que régit ce chapitre : `DomibusClient` joint la passerelle par `URL_BASE_DOMIBUS`, une URL `https://` dans un déploiement réel, et hérite donc du profil. C'est assumé, pour deux raisons. La granularité par connexion n'existe pas dans `Net::HTTP` ; et ce que le profil fait à ce saut-là est un **durcissement** — trois suites ajoutées et aucune retirée, plancher de version relevé, un seul groupe écarté pour être en deçà du plancher recommandé, les cinq courbes du §3.4 restant offertes. Le profil eDelivery du [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931), qui régit ce saut, exige lui aussi TLS 1.2 au minimum.

### Comment la base a été établie, et comment relire le profil appliqué

Les listes exactes ne se déduisent pas d'une documentation : elles se lisent dans le `ClientHello` que le client émet. Celui de l'image nue — le point de départ, contre lequel se mesure ce que le profil ajoute — se capture en faisant dialoguer un contexte OpenSSL Ruby par défaut avec un `s_server -trace`, dans l'image épinglée elle-même :

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

Pour lire ce que l'application offre réellement, c'est-à-dire le profil appliqué, la même capture se rejoue en chargeant l'initializer — `bundle exec rails runner` dans le conteneur `web`, avec le même `s_server -trace` en face. On y voit alors les trois suites CCM présentes — `TLS_AES_128_CCM_SHA256` après les trois suites TLS 1.3 du défaut, les deux `ECDHE-ECDSA-…-CCM` en fin de liste, l'ordre de préférence du chapitre étant conservé —, et `supported_groups` réduit à `X25519MLKEM768, x25519, secp256r1, x448, secp384r1, secp521r1, ffdhe3072` — le premier en moins là où l'OpenSSL lié l'ignore.

> [!IMPORTANT]
> **Le profil dépend de l'OpenSSL auquel le processus est lié, qui n'est pas la version de Ruby qu'on épingle.** Les trois setters n'échouent pas de la même façon : `ciphers=` et `ciphersuites=` **écartent silencieusement** un nom qu'ils ne résolvent pas et gardent le reste — une suite peut donc manquer sans que rien ne le dise —, tandis que `SSL_CTX_set1_groups_list` **rejette la liste entière** sur un seul nom inconnu. Comme le profil s'applique à tout contexte du processus, un groupe inconnu ferait échouer *toutes* les connexions sortantes : c'est pourquoi `TlsProfile` filtre les groupes par ce que le build accepte, et pourquoi `X25519MLKEM768` — apparu dans OpenSSL 3.5 — est offert là où il existe et absent ailleurs, sans que la conformité au §3.4 en dépende. Un runner d'intégration continue nu et l'image `ruby:4.0.6-slim` ne s'accordent pas sur ce point.

C'est cependant `spec/initializers/tls_profile_spec.rb` qui en fait une garantie plutôt qu'une observation : il lit les suites offertes par un contexte réel, et il fait échouer une poignée de main en boucle locale contre un serveur borné à TLS 1.1 puis contre un serveur n'offrant que `ffdhe2048`. Chaque refus y est doublé de sa contre-épreuve — la même poignée de main par un contexte que le profil n'a pas touché, qui réussit —, sans quoi la suite passerait au vert sur la seule bienveillance d'OpenSSL, ce dont ce dépôt a précisément cessé de dépendre.

## Le tableau des verdicts

| Exigence | Force | Ce que fait la configuration réelle | Verdict |
| --- | --- | --- | --- |
| §3.1 — « *It MUST be possible to configure the accepted TLS version(s) in the TLS implementation* » | MUST | La possibilité existe et **elle est exercée** : `TlsProfile::PROFILE` porte `min_version: OpenSSL::SSL::TLS1_2_VERSION`. | **satisfaite** |
| §3.1 — « *It MUST be possible to configure accepted TLS cipher suites in the TLS implementation* » | MUST | Idem : le profil pose `ciphers` et `ciphersuites`, les deux listes que le §3.3 vise. | **satisfaite** |
| §3.2 — « *MUST NOT use SSL 3.0, TLS 1.0 and 1.1* » | MUST NOT | Le plancher vient du profil, non du défaut de l'image : une poignée de main contre un serveur borné à TLS 1.1 échoue, y compris sur un contexte dont les réglages propres l'accepteraient — c'est ce que vérifie `spec/initializers/tls_profile_spec.rb`. | **satisfaite** |
| §3.2 — « *MUST therefore at a minimum support TLS 1.2* » | MUST | TLS 1.2 est annoncé et négocié avec succès contre un serveur qui n'offre que lui. | **satisfaite** |
| §3.2 — « *SHOULD support the use of TLS 1.3* » | SHOULD | TLS 1.3 est annoncé en premier et effectivement négocié avec `query.cs.acc.oots.tech.ec.europa.eu`. | **satisfaite** |
| §3.3 — suites TLS 1.3 : `TLS_AES_128_GCM_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_AES_128_CCM_SHA256`, plus `TLS_CHACHA20_POLY1305_SHA256` en option | SHOULD | Les quatre sont offertes : `TlsProfile::CIPHERSUITES` écrit les trois du défaut d'OpenSSL et y ajoute `TLS_AES_128_CCM_SHA256`, que celui-ci ne portait pas. | **satisfaite** |
| §3.3 — suites TLS 1.2 à confidentialité persistante énumérées par le chapitre | SHOULD | Les six sont offertes : aux quatre `ECDHE_{ECDSA,RSA}_AES{128,256}_GCM_SHA{256,384}` du défaut, `TlsProfile::CIPHERS` ajoute `ECDHE-ECDSA-AES256-CCM` et `ECDHE-ECDSA-AES128-CCM`. Le client offre par ailleurs les suites que le chapitre n'énumère pas et qu'OpenSSL offrait déjà, ce qui ne lui en est pas un écart : le §3.3 le permet expressément — « *Further cipher suites may be used when following specific regulations.* » | **satisfaite** |
| §3.4 — courbes : `secp256r1`, `secp384r1`, `secp521r1`, `x25519`, `x448` | SHOULD | Les cinq sont dans `TlsProfile::GROUPS`, précédées de `X25519MLKEM768` là où l'OpenSSL lié le connaît — un groupe hybride post-quantique que le chapitre ne connaît pas et n'interdit pas. | **satisfaite** |
| §3.4 — « *at least ffdhe3072 should be used* » | SHOULD | `ffdhe3072` est le seul groupe à corps fini offert : `ffdhe2048` a été retiré de la liste, donc ne peut plus être préféré. | **satisfaite** |
| §3.5 — profil de certificat (`digitalSignature`, `serverAuth` obligatoires, `clientAuth` interdit, `cA = false`, `subjectAltName`, validité ≤ 398 jours…) | MUST | Le titre de la section est « *Certificate Profile for TLS Server Certificates* » : ces exigences pèsent sur les certificats **serveur** des Common Services, que ce dépôt ne délivre pas. | **sans objet** |
| §3.5 + §4 — corollaire : `clientAuth` interdit, donc **aucun TLS mutuel** vers les Common Services | MUST NOT | Aucune connexion ne fixe `client_cert` ni `client_key`, et `Net::HTTP#cert` vaut `nil` par défaut : le client ne présente aucun certificat. La vérification du certificat serveur, elle, reste active (`VERIFY_PEER` et `verify_hostname` viennent de `DEFAULT_PARAMS`). | **satisfaite** |
| §4 — « *Access to the OOTS common services by clients using the REST interface shall be public* » | SHALL | Exigence adressée aux *providers of OOTS common services*, pas au client. Ce dépôt n'en délivre aucun. | **sans objet** |
| §4 — « *Clients should limit unnecessary access* » et « *proxy caching* » | SHOULD | Tout est mis en cache pour `DUREE_CACHE_SERVICES_COMMUNS` (3 600 s en acceptation) : la résolution NAPTR dans `CommonServicesInstance`, les réponses des annuaires dans `CommonServicesQuery`, les listes de codes dans `CodeListClient` ; les clés publiques des requêtants le sont cinq minutes dans `JwksFetcher`. Les reprises sont bornées (`retry, max: 2`, `backoff_factor: 2`) et le délai d'attente à `DELAI_MAX_SERVICES_COMMUNS`, soit 10 s. | **satisfaite** |
| §4 — « *rate limiting and/or other technical measures may be applied* » | MAY | Faculté ouverte aux *common service operators*. Côté client, rien à appliquer. | **sans objet** |
| §2 — « *It is RECOMMENDED that all DNS record lookups in OOTS are secured using DNSSEC* » | RECOMMENDED | `CommonServicesInstance#records` interroge par `Resolv::DNS`, qui **ne connaît pas DNSSEC** : le mot n'apparaît pas dans `resolv.rb`, la bibliothèque ne pose pas le bit DO et ne lit pas le bit AD. La validation, si elle a lieu, a lieu dans le résolveur du système — que ce dépôt ne fixe pas. | **non établi** |

**Récapitulatif : 11 satisfaites, 1 non établie, 3 sans objet.**

## Ce que le profil ajoute, et ce qu'il se garde de retirer

Le profil **n'ajoute que**. Aux suites qu'OpenSSL offrait déjà, il en ajoute trois ; au plancher qu'OpenSSL posait de lui-même, il substitue le même plancher, mais écrit ici. La seule soustraction est `ffdhe2048`, retiré parce que le §3.4 pose un plancher sur ce qui est *employé* et qu'un correspondant mal configuré pouvait sans cela emmener l'échange dessous.

Cette retenue est délibérée, et c'est la principale chose à savoir avant de toucher à ce fichier. Les deux listes du §3.3 sont introduites par « *should support the following* » : elles obligent à **offrir** celles-là, elles n'interdisent d'en offrir aucune autre. Le chapitre le dit de surcroît en toutes lettres — « *Further cipher suites may be used when following specific regulations* » — et aucune de ses phrases n'interdit une suite, n'interdit le mode CBC, ni n'exige la confidentialité persistante. Lire ces listes comme une liste blanche à faire respecter est la faute qui a fait ouvrir [OOTS-156](https://linear.app/pole-api/issue/OOTS-156), annulé pour cela. `spec/initializers/tls_profile_spec.rb` en fait une assertion : tout ce qu'un contexte non profilé offre, le contexte profilé l'offre encore.

Le même raisonnement vaut au §3.4, et c'est pourquoi `X25519MLKEM768` reste en tête des groupes bien que le chapitre ne le nomme pas : il est antérieur à ce mécanisme d'échange, et retirer une clé hybride post-quantique pour se conformer à une énumération plus ancienne qu'elle serait un affaiblissement obtenu au nom de la conformité.

> [!IMPORTANT]
> **La liste des suites TLS 1.2 est dérivée de celle du contexte par défaut, puis augmentée** ; elle ne peut pas s'écrire en chaîne OpenSSL. Les suites CCM vivent dans `COMPLEMENTOFDEFAULT`, que le mot-clé `DEFAULT` supprime par un `!`, et OpenSSL ne réintroduit jamais une suite qu'un `!` a supprimée : `ciphers = 'DEFAULT:ECDHE-ECDSA-AES256-CCM'` n'offre **aucune** suite CCM. Qui voudra « simplifier » la dérivation en chaîne littérale obtiendra une liste silencieusement amputée.

> [!WARNING]
> `config.cache_store` n'est pas déclaré en production (`config/environments/production.rb` le laisse commenté), donc Rails retombe sur son `:file_store` de `tmp/cache`. Le cache existe et répond au *should* du §4, mais **il n'est partagé entre `web` et `worker` que par le montage du volume de la pile locale** : un déploiement où les deux processus ne partagent pas ce répertoire double les appels aux annuaires sans que rien ne le dise.

## Ce que ce document ne couvre pas

- **La signature détachée des réponses** (`oots-response-sig`), qui relève du [chapitre 3.6](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932954) : elle est vérifiée par `CommonServicesSignature` contre le magasin de `CERTIFICATS_SERVICES_COMMUNS`. Le chapitre 3.7 place délibérément cette garantie **au-dessus** du transport, parce que le [chapitre 3.4](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932916) invite à intercaler un cache mandataire qui terminerait TLS.
- **Le transport AS4 vers la passerelle**, qui suit le profil eDelivery du [chapitre 4.7](https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931) et la configuration de Domibus, non ce chapitre-ci — voir [domibus_context.md](domibus_context.md). Le profil TLS posé ici l'atteint néanmoins, faute de granularité par connexion : c'est l'objet de l'avertissement en tête de document.
- **Le TLS que les fournisseurs de service français rencontrent en appelant cette application** : c'est un mandataire inverse qui le termine (`config.assume_ssl` et `config.force_ssl` en production), et le chapitre 3.7 ne régit que l'accès *aux* Common Services.
