# Identités de test

Les identités de test dont on se sert en acceptation, quand la démarche de démonstration demande un justificatif à un autre État membre.

On peut déjà en trouver plein ici : https://ec.europa.eu/digital-building-blocks/wikis/spaces/SDGOO/pages/781911521/Belgium+testing+information

## Pologne

> Note : Il faut utiliser le fake-france-connect sinon on n'envoie pas de eIDAS identifier, ce qui fait que l'Autriche ne répond pas.

Pour les exigences :

- (TEST) Test requirement
- CEIDG certificate

Choisir l'option « Trusted Profile » (« Profil zaufany » en polonais) :

- eIDAS identifier : PL/FR/91040665144
- identifiant : `Alicja_Roszponka`
- mot de passe : `zaq12wsxCDE#`
- code du second facteur : `12345678`

For missing evidence :

- eIDAS identifier : PL/FR/95032932124
- identifiant : Laura_Lento
- birthdate : 1995-03-29
- mot de passe : zaq12wsxCDE#2
- code du second facteur : 12345678
- use "CEIDG certificate"


La Pologne publie aussi son portail de démarche de test, côté requêteur : [qa-procedure-portal.pit.lukasiewicz.gov.pl/requester](https://qa-procedure-portal.pit.lukasiewicz.gov.pl/requester).

## Belgique

Pour demander un justificatif belge, la Belgique a délivré à la France une identité de test :

- identifiant : `FranceOots`
- mot de passe : `Oots_96460103047`

L'identité qu'elle porte, à retrouver dans ce que la Belgique reçoit :

- identifiant eIDAS : `FR/BE/NyJeCxsRdhcjChApRk1cNyFOBQI2IgpSFho4FD4aQylbA1wsKRpdQHZmAABJR3xFcQ==`
- nom : France Oots
- date de naissance : 1996-01-06
- pays : France

## Autriche

Les identités ID Austria prédéfinies, avec leurs identifiants et mots de passe, sont publiées et tenues à jour par l'Autriche sur la page [Vordefinierte Testidentitäten](https://www.id-austria.gv.at/de/developer/testen/vordefinierte-testidentit%C3%A4ten) : en prendre une là plutôt que d'en recopier ici.


# TODO for accelerometer
TODO to reach level 4 :
- dns lookup for common services : countries can have their own instance of common services (italy does)
- signature verification of Common services responses (maybe already done ?)
- check boxes in https://ec.europa.eu/digital-building-blocks/wikis/spaces/SDGOO/pages/842026077/FR+-+France+-+OOTS+Acceleratormeter+levels
- fill documents and upload them in it (I have romanian examples)
  - Access Point readiness indicators
  - Common Services readiness indicators