# language: fr
Fonctionnalité: Se connecter à l'espace d'administration

  L'espace d'administration est réservé à l'équipe qui exploite le service.
  Chacune de ses pages demande à l'administrateur de se connecter, y compris
  le tableau de bord des jobs.

  Scénario: sans connexion, le journal des événements n'est pas lisible
    Étant donné un échange en échec avec l'Allemagne
    Quand un visiteur ouvre le journal des événements
    Alors la page de connexion s'affiche
    Et la page n'affiche pas l'échange allemand

  Scénario: sans connexion, le tableau de bord des jobs n'est pas lisible
    Quand un visiteur ouvre le tableau de bord des jobs
    Alors la page de connexion s'affiche

  Scénario: un mot de passe incorrect n'ouvre pas l'espace d'administration
    Étant donné un compte d'administrateur
    Quand l'administrateur se connecte avec un mot de passe incorrect
    Alors la page de connexion dit que les identifiants sont refusés

  Scénario: se déconnecter ferme l'espace d'administration
    Étant donné un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration
    Quand l'administrateur se déconnecte
    Et qu'il ouvre le journal des événements
    Alors la page de connexion s'affiche
