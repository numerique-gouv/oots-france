# language: fr
@bout_en_bout
Fonctionnalité: Identifier l'usager de la démarche par la cinématique européenne

  La démarche de démonstration traverse ici FranceConnect+ pour de bon : le
  bouton de l'accueil, la page de choix du pays de la passerelle eIDAS,
  l'identité de test danoise, le consentement, puis le retour sur le formulaire
  de demande, identifié.

  Le FranceConnect+ traversé est le faux d'OOTS-186, que la suite lance à côté
  du scénario : le bac à sable attend un déploiement joignable, que
  l'intégration continue ne lui donne pas. La démarche, elle, ne le distingue
  pas du vrai — elle ne connaît le portail que par son document de découverte.

  Ce que le faux ne peut pas éprouver — un identifiant eIDAS mal formé, une
  signature hors de son JWKS, un niveau inférieur à celui demandé — est éprouvé
  par `make test`, qui tient ces trois refus.

  Contexte:
    Étant donné un faux FranceConnect+ qui tourne à côté du scénario
    Et un exploitant connecté à la console

  Scénario: un étudiant danois s'identifie et retrouve son identité sur le formulaire
    Quand il ouvre la démarche de démonstration
    Et qu'il suit le bouton de la cinématique européenne
    Alors la page de choix du pays de la passerelle s'ouvre
    Quand il choisit le pays "DK" sur la page de la passerelle
    Et qu'il choisit l'identité de test "dk-substantial"
    Et qu'il confirme la transmission de ses données
    Alors il arrive sur le formulaire de demande de bourse
    Et le formulaire porte "Nom de famille" à "Sørensen"
    Et le formulaire porte "Prénom(s)" à "Freja Marie"
    Et le formulaire porte "Date de naissance" à "2001-04-17"
    Et le formulaire porte "Niveau de garantie" à "Substantial"
    Et le formulaire porte "Provenance de l'identité" à "Identité d'un autre État membre, par la passerelle eIDAS"
    Et le formulaire porte "Identifiant eIDAS" à "Non rendu par l'authentification"
    Et le formulaire porte "Sexe" à "Féminin"
    Et le formulaire porte "Lieu de naissance" à "Aarhus"
    Et le formulaire n'offre aucun champ de saisie
    Et le formulaire ne montre pas l'identifiant que FranceConnect+ lui a donné

  Scénario: le niveau élevé s'affiche tel qu'il a été atteint, et rien n'est inventé
    Quand il s'identifie comme "dk-high"
    Alors le formulaire porte "Niveau de garantie" à "High"
    Et le formulaire ne dit ni le sexe ni le lieu de naissance

  Scénario: une rotation des clés de signature n'empêche pas l'identification
    Quand le faux change de clé de signature
    Et qu'il s'identifie comme "dk-substantial"
    Alors il arrive sur le formulaire de demande de bourse
    Et le formulaire porte "Nom de famille" à "Sørensen"

  Scénario: se déconnecter ferme la session FranceConnect+ et l'identité avec
    Quand il s'identifie comme "dk-substantial"
    Et qu'il se déconnecte de la console
    Alors FranceConnect+ le ramène sur la page de déconnexion de la démarche
    Quand il se reconnecte à la console
    Et qu'il ouvre le formulaire de demande de bourse
    Alors la démarche le renvoie à son accueil, sans identité
