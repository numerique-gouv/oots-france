# AP problem (germany)

Le journal tranche : le blocage vient du côté allemand. Leur serveur renvoie un 403 Forbidden à notre message. Ni TLS, ni notre configuration, ni leur certificat ne sont en cause.

Rapport : AP_FR_01 → AP_DE_IP_DATAPORT_TEST

- Symptôme : chaque message AS4 que nous envoyons à https://edap-test.noots.gov.de/domibus/services/msh échoue en EBMS:0005 Error dispatching message. Domibus a fait 5 tentatives le 24 nov. entre 11h24 et 11h36 (message 1bc595b7-…@oots.eu), puis le test de connectivité de 16h32 (396c409d-…@domibus.eu) a échoué aussi.
- Cause, d'après le journal de Domibus : HTTP response '403: Forbidden' when communicating with https://edap-test.noots.gov.de/domibus/services/msh. La connexion TLS s'établit, la requête HTTP arrive chez eux, et c'est leur serveur qui la refuse.
- Pourquoi ce n'est pas notre faute :
  - Le journal ne contient aucune erreur TLS : pas de SSLHandshakeException, pas de PKIX.
  - Leur certificat serveur est valide (D-Trust, émis le 5 nov. 2026), et ils ne demandent pas de certificat client.
  - Le même 403 est renvoyé à une simple requête GET envoyée depuis une autre adresse IP.
  - Si leur passerelle ne connaissait pas notre PMode ou notre certificat de signature, elle répondrait par une erreur ebMS, pas par un 403 HTTP. Les autres points d'accès « connectés » montrent que notre côté fonctionne.
- Cause la plus probable : un filtrage par adresse IP, un pare-feu applicatif ou un reverse proxy devant leur Domibus.
- Ce qu'il faut leur demander : d'autoriser l'IP sortante de oots.infra.data.gouv.fr, que tu obtiens avec curl -s ifconfig.me sur le serveur. S'ils filtrent sur autre chose, il faut qu'ils disent quoi.

Un message en anglais à leur envoyer :

Hello, our access point AP_FR_01 cannot reach AP_DE_IP_DATAPORT_TEST. Every AS4 message to https://edap-test.noots.gov.de/domibus/services/msh gets an HTTP 403 Forbidden from your side (latest attempt: 2026-11-24 16:32 CET, message 396c409d-e81c-11f1-ba1b-16b445dc9d85@domibus.eu). The TLS handshake succeeds; the refusal comes at HTTP level, before your Domibus processes the message. Could you check whether an IP allow-list or a WAF sits in front of your MSH, and allow our outgoing IP <IP>? Thanks.