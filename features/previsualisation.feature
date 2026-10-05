# language: fr
@bout_en_bout
Fonctionnalité: Montrer le justificatif à l'usager avant de l'envoyer

  Un requêteur étranger demande un justificatif en exigeant que l'usager le
  voie d'abord. La France lui répond l'adresse de son espace de
  prévisualisation, l'usager y consulte le document et choisit de l'utiliser
  ou non, puis la seconde requête du requêteur étranger reçoit exactement ce
  que l'usager a accepté.

  Le requêteur étranger forge ses requêtes et l'usager suit l'adresse dans un
  navigateur ; ce que la France répond se lit dans le journal des échanges.
  docs/test_e2e.md dit ce que ces scénarios demandent pour tourner.

  Contexte:
    Étant donné un portail de démarche français déclaré dans l'annuaire des requêteurs
    Et un requêteur étranger qui forge ses requêtes

  Scénario: l'usager accepte le document, et la seconde requête le reçoit
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Alors la page affiche le lien vers le document
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie le document que l'usager a vu
    Et l'espace ramène l'usager à l'adresse de retour

  Scénario: l'usager refuse le document, et la seconde requête reçoit une liste vide
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Et que l'usager ouvre l'espace de prévisualisation
    Et que l'usager choisit "Ne pas l'utiliser" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie une réponse sans justificatif

  Scénario: un requêteur étranger en "oots-edm:v1.2" reçoit le document que l'usager a accepté
    Quand le requêteur étranger envoie en "oots-edm:v1.2" une requête qui exige la prévisualisation
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace et la méthode "GET"
    Quand l'usager ouvre l'espace de prévisualisation avec une adresse de retour
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Alors l'espace ramène l'usager à l'adresse de retour
    Quand le requêteur étranger envoie en "oots-edm:v1.2" la seconde requête avec l'adresse de l'espace
    Alors la France envoie le document que l'usager a vu

  Scénario: l'espace rouvert après le choix n'offre plus de choix
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Et que l'usager ouvre l'espace de prévisualisation
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager rouvre l'espace de prévisualisation
    Alors la page ne propose plus de choisir
