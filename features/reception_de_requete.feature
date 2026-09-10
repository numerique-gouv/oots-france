# language: fr
@bout_en_bout
Fonctionnalité: Recevoir la requête d'un autre État membre

  La France reçoit ici des requêtes qu'un requêteur étranger a forgées : une
  requête construite avec les outils du dépôt, altérée, puis soumise à la
  passerelle comme le ferait un vrai requêteur. C'est le seul moyen d'éprouver
  ses refus à travers un vrai transport, puisque les requêtes qu'elle
  s'envoie à elle-même sont conformes par construction.

  Ce que la France répond se lit dans le journal des échanges, qu'aucune page
  n'expose : il contient des données personnelles.

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
