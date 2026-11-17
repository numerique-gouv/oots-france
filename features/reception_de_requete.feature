# language: fr
@bout_en_bout
Fonctionnalité: Recevoir la requête d'un autre État membre

  La France reçoit ici des requêtes qu'un requêteur étranger a forgées : une
  requête construite avec les outils du dépôt, altérée, puis soumise à la
  passerelle comme le ferait un vrai requêteur. C'est le seul moyen d'éprouver
  ses refus à travers un vrai transport, puisque les requêtes qu'elle
  s'envoie à elle-même sont conformes par construction.

  Ce que la France répond se lit dans le journal des échanges, qu'aucune page
  n'expose : il contient des données personnelles. Le statut étudiant se lit
  au bac à sable d'API Particulier, que la pile doit joindre.

  Contexte:
    Étant donné un portail de démarche français déclaré dans l'annuaire des requêteurs
    Et un requêteur étranger qui forge ses requêtes

  Scénario: une requête sans un slot obligatoire est refusée
    Quand le requêteur étranger envoie une requête sans le slot "PossibilityForPreview"
    Alors la France refuse la requête avec le code "EDM:ERR:0003" et la règle "R-EDM-REQ-S009"
    Et la France n'envoie aucun justificatif

  Scénario: une requête qui déclare deux sujets est refusée
    Quand le requêteur étranger envoie une requête qui déclare aussi une personne morale
    Alors la France refuse la requête avec le code "EDM:ERR:0003" et la règle "R-EDM-REQ-S016"
    Et la France n'envoie aucun justificatif

  Scénario: une requête qui rejoue un identifiant déjà traité est refusée
    Quand le requêteur étranger envoie deux fois la même requête
    Alors la France sert la première requête
    Et la France refuse la seconde requête avec le code "EDM:ERR:0003", au motif du chapitre 4.4

  Scénario: une requête d'un type que la France ne détient pas est refusée, quelle que soit la démarche
    Quand le requêteur étranger envoie une requête sous la démarche "T1" pour un type que la France ne détient pas
    Alors la France refuse la requête avec le code "EDM:ERR:0004"
    Et la France n'envoie aucun justificatif

  Scénario: le statut étudiant est lu chez API Particulier et servi en JSON
    Quand le requêteur étranger envoie une requête pour le statut étudiant de Martin Jacques, né à "75102"
    Alors la France sert le statut étudiant en "application/json"

  Scénario: le statut étudiant demandé en PDF est l'attestation d'API Particulier
    Quand le requêteur étranger envoie une requête pour le statut étudiant de Martin Jacques, né à "75102", en "application/pdf"
    Alors la France sert le statut étudiant en "application/pdf"

  Scénario: le statut étudiant d'une personne qu'API Particulier ne connaît pas est une liste vide
    Quand le requêteur étranger envoie une requête pour le statut étudiant d'une personne qu'API Particulier ne connaît pas
    Alors la France répond une liste vide, sans justificatif
    Et la fiche de l'échange affiche "Aucun justificatif"

  Scénario: une requête sans prévisualisation pour un type auquel aucun document ne correspond reçoit une liste vide
    Quand le requêteur étranger envoie une requête sans prévisualisation pour le type "FR - Test without evidence match (TC18)"
    Alors la France répond une liste vide, sans justificatif
    Et la fiche de l'échange affiche "Aucun justificatif"
    Et le journal de l'échange ne contient aucune ligne "Prévisualisation terminée"

  Scénario: une requête en "oots-edm:v1.2" est servie dans sa propre version
    Quand le requêteur étranger envoie une requête en "oots-edm:v1.2"
    Alors la France sert le justificatif dans une réponse en "oots-edm:v1.2"

  Scénario: une requête dont l'entête et le corps annoncent deux versions est refusée
    Quand le requêteur étranger envoie une requête dont l'entête dit "oots-edm:v2.0" et le corps "oots-edm:v1.2"
    Alors la France refuse la requête avec le code "EDM:ERR:0003" et la règle "R-EDM-REQ-C001"
    Et la France n'envoie aucun justificatif
