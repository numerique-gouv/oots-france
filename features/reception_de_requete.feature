# language: fr
@bout_en_bout
Fonctionnalité: Recevoir la requête d'un autre État membre

  L'échange de bout en bout boucle sur la seule passerelle du PMode d'exemple :
  la France ne reçoit donc jamais que des requêtes qu'elle a elle-même
  construites, conformes par construction et sous un identifiant neuf. Les
  refus qu'imposent les chapitres 4.6 et 4.4 ne seraient ainsi éprouvés nulle
  part où le transport est réel.

  Un faux correspondant comble ce manque : il forge une requête avec les
  constructeurs du dépôt, altère le corps rendu, et la soumet au plugin WS
  comme le ferait un vrai. Ce que la France en fait se lit dans le journal,
  qu'aucune route n'expose — il porte des données personnelles.

  Contexte:
    Étant donné une démarche française déclarée dans l'annuaire
    Et un correspondant étranger capable de forger ses requêtes

  Scénario: une requête à laquelle manque un slot obligatoire est refusée
    Quand le correspondant envoie une requête sans son slot "PossibilityForPreview"
    Alors la France refuse par "EDM:ERR:0003" en invoquant la règle "R-EDM-REQ-S009"
    Et aucun justificatif n'est parti

  Scénario: une requête déclarant deux sujets à la fois est refusée
    Quand le correspondant envoie une requête déclarant aussi une personne morale
    Alors la France refuse par "EDM:ERR:0003" en invoquant la règle "R-EDM-REQ-S016"
    Et aucun justificatif n'est parti

  Scénario: une requête rejouant un identifiant déjà traité est refusée
    Quand le correspondant envoie deux fois la même requête
    Alors la France sert la première
    Et la France refuse la seconde par "EDM:ERR:0003" en invoquant le chapitre 4.4
