# language: fr
@bout_en_bout
Fonctionnalité: Montrer le justificatif à l'usager avant de l'envoyer

  Un requêteur étranger demande un justificatif en exigeant que l'usager le
  voie d'abord. La France lui répond l'adresse de son espace de
  prévisualisation, où l'usager s'identifie de nouveau avant d'y consulter le
  document et de choisir de l'utiliser ou non ; la seconde requête du
  requêteur étranger reçoit exactement ce que l'usager a accepté. Un usager
  qui s'identifie sous une autre identité que celle de la requête ne voit
  rien, et la seconde requête reçoit l'erreur d'authentification. Pour un
  type auquel aucun document ne correspond, l'usager lit sur l'espace
  qu'aucun ne lui correspond, et la seconde requête reçoit une liste vide. Le
  statut étudiant est lu au bac à sable d'API Particulier dès la requête quand
  elle porte le sexe et le code de la commune de naissance, sinon une fois
  l'usager identifié, sur l'identité que FranceConnect+ certifie : il
  s'affiche sur l'espace au lieu d'un document, ou son attestation y est
  offerte comme un document quand la requête la demande.

  Le requêteur étranger forge ses requêtes au nom d'une identité de test du
  faux FranceConnect+, et l'usager suit l'adresse dans un navigateur ; ce que
  la France répond se lit dans le journal des échanges. docs/test_e2e.md dit
  ce que ces scénarios demandent pour tourner.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et un portail de démarche français déclaré dans l'annuaire des requêteurs
    Et un requêteur étranger qui forge ses requêtes

  Scénario: l'usager accepte le document, et la seconde requête le reçoit
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Alors la page affiche le lien vers le document
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie le document que l'usager a vu
    Et l'espace ramène l'usager à l'adresse de retour

  Scénario: l'usager refuse le document, et la seconde requête reçoit une liste vide
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Et que l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Et que l'usager choisit "Ne pas l'utiliser" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie une réponse sans justificatif
    Et la fiche de l'échange affiche "Refusé par l'usager"
    Et le journal de l'échange contient une seule ligne "Prévisualisation terminée" de détail "refused"

  Scénario: un requêteur étranger en "oots-edm:v1.2" reçoit le document que l'usager a accepté
    Quand le requêteur étranger envoie en "oots-edm:v1.2" une requête qui exige la prévisualisation
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace et la méthode "GET"
    Quand l'usager ouvre l'espace de prévisualisation avec une adresse de retour
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Alors l'espace ramène l'usager à l'adresse de retour
    Quand le requêteur étranger envoie en "oots-edm:v1.2" la seconde requête avec l'adresse de l'espace
    Alors la France envoie le document que l'usager a vu

  Scénario: l'espace rouvert après le choix n'offre plus de choix
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Et que l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager rouvre l'espace de prévisualisation
    Alors la page ne propose plus de choisir

  Scénario: l'usager qui s'identifie sous une autre identité ne voit rien, et la seconde requête reçoit "EDM:ERR:0001"
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation
    Et que l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-high"
    Alors la page dit que le document ne peut pas être fourni
    Quand le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France répond "EDM:ERR:0001" à la seconde requête, sans adresse de prévisualisation

  Scénario: aucun document ne correspond à l'usager, qui le lit sur l'espace, et la seconde requête reçoit une liste vide
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation pour le type "FR - Test without evidence match (TC18)"
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Alors la page dit qu'aucun document ne correspond à l'usager
    Quand l'usager rouvre l'espace de prévisualisation
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie une réponse sans justificatif
    Et la fiche de l'échange affiche "Aucun justificatif"
    Et le journal de l'échange contient une seule ligne "Prévisualisation terminée" de détail "unmatched"

  Scénario: un requêteur étranger en "oots-edm:v1.2" reçoit une liste vide quand aucun document ne correspond à l'usager
    Quand le requêteur étranger envoie en "oots-edm:v1.2" une requête qui exige la prévisualisation pour le type "FR - Test without evidence match (TC18)"
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace et la méthode "GET"
    Quand l'usager ouvre l'espace de prévisualisation avec une adresse de retour
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Alors la page dit qu'aucun document ne correspond à l'usager
    Et la page propose de revenir à l'adresse de retour
    Quand le requêteur étranger envoie en "oots-edm:v1.2" la seconde requête avec l'adresse de l'espace
    Alors la France envoie une réponse sans justificatif
    Et la fiche de l'échange affiche "Aucun justificatif"
    Et le journal de l'échange contient une seule ligne "Prévisualisation terminée" de détail "unmatched"

  Scénario: l'usager lit son statut étudiant sur l'espace et l'accepte, et la seconde requête le reçoit
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation du statut étudiant de Martin Jacques
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "etudiant-inscrit"
    Alors la page affiche le statut étudiant de l'usager, sans lien vers un document
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie le statut étudiant en "application/json"

  Scénario: l'usager lit son statut étudiant, ouvre son attestation et l'accepte, et la seconde requête la reçoit
    Quand le requêteur étranger envoie une requête qui exige la prévisualisation du statut étudiant de Martin Jacques, en "application/pdf"
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "etudiant-inscrit"
    Alors la page affiche le lien vers le document, sans le statut étudiant
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie le statut étudiant en "application/pdf"
    Et la France envoie le document que l'usager a vu

  Scénario: sans le sexe ni le lieu de naissance dans la requête, la France lit le statut étudiant sur l'identité que FranceConnect+ certifie
    Quand le requêteur étranger envoie une requête pour le statut étudiant de Martin Jacques, sans son sexe ni son lieu de naissance
    Alors la France répond "EDM:ERR:0002" avec l'adresse de son espace de prévisualisation
    Quand l'usager ouvre l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "etudiant-inscrit"
    Alors la page affiche le statut étudiant de l'usager, sans lien vers un document
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que le requêteur étranger envoie la seconde requête avec l'adresse de l'espace et une adresse de retour
    Alors la France envoie le statut étudiant en "application/json"
