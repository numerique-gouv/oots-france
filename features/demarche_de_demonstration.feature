# language: fr
@bout_en_bout
Fonctionnalité: Identifier l'usager de la démarche de démonstration par la cinématique européenne

  L'administrateur tient ici le rôle d'un étudiant danois qui fait une demande
  de bourse : il part de la page d'accueil de la démarche de démonstration,
  passe par FranceConnect+ et la passerelle eIDAS, choisit son pays et une
  identité de test, consent à la transmission de ses données, puis revient sur
  le formulaire de demande, identifié.

  La suite ne traverse pas le vrai FranceConnect+ mais le faux FranceConnect+
  qu'elle lance à côté des scénarios, parce que le bac à sable de
  FranceConnect+ ne répond qu'à un déploiement joignable. La démarche ne fait pas la différence : elle ne
  connaît FranceConnect+ que par son document de découverte. docs/test_e2e.md
  dit ce que ce faux reproduit et ce qu'il laisse à la suite unitaire.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et l'administrateur de démonstration connecté à l'espace d'administration

  Scénario: un étudiant danois s'identifie et retrouve son identité sur le formulaire
    Quand l'administrateur ouvre la démarche de démonstration
    Et qu'il clique sur le bouton de la cinématique européenne
    Alors l'administrateur arrive sur la page de choix du pays
    Quand l'administrateur choisit le pays "DK"
    Et que l'administrateur choisit l'identité de test "dk-substantial"
    Et que l'administrateur consent à la transmission de ses données
    Alors l'administrateur arrive sur le formulaire de demande de bourse
    Et le formulaire affiche "Nom de famille" : "Sørensen"
    Et le formulaire affiche "Prénom(s)" : "Freja Marie"
    Et le formulaire affiche "Date de naissance" : "2001-04-17"
    Et le formulaire affiche "Niveau de garantie" : "Substantial"
    Et le formulaire affiche "Provenance de l'identité" : "Identité d'un autre État membre, par la passerelle eIDAS"
    Et le formulaire affiche "Identifiant eIDAS" : "Non rendu par l'authentification"
    Et le formulaire affiche "Sexe" : "Féminin"
    Et le formulaire affiche "Lieu de naissance" : "Aarhus"
    Et le formulaire affiche l'identité sans aucun champ de saisie
    Et le formulaire n'affiche pas le pseudonyme que FranceConnect+ a donné à l'usager

  Scénario: le niveau de garantie affiché est celui que l'usager a atteint
    Quand l'administrateur s'identifie avec l'identité de test "dk-high"
    Alors le formulaire affiche "Niveau de garantie" : "High"
    Et le formulaire n'affiche ni le sexe ni le lieu de naissance

  Scénario: une rotation des clés de signature de FranceConnect+ n'empêche pas l'identification
    Quand le faux FranceConnect+ change de clé de signature
    Et que l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Alors l'administrateur arrive sur le formulaire de demande de bourse
    Et le formulaire affiche "Nom de famille" : "Sørensen"

  Scénario: se déconnecter ferme aussi la session FranceConnect+
    Quand l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Et qu'il se déconnecte de l'espace d'administration
    Alors FranceConnect+ le ramène sur la page de déconnexion de la démarche
    Quand il se reconnecte à l'espace d'administration
    Et qu'il ouvre le formulaire de demande de bourse
    Alors l'administrateur arrive sur la page d'accueil de la démarche de démonstration, sans identité
