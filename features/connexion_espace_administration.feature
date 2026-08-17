# language: fr
Fonctionnalité: Se connecter à l'espace d'administration

  L'espace est réservé à l'équipe qui exploite le service. Chaque page en
  demande la connexion, y compris le tableau de bord des jobs, qui est un
  moteur monté et qu'aucun filtre de l'application n'atteint.

  Scénario: sans connexion, la liste des conversations n'est pas lisible
    Étant donné une conversation en échec avec l'Allemagne
    Quand j'ouvre la liste des conversations
    Alors on me demande de me connecter
    Et je ne vois plus la conversation allemande

  Scénario: sans connexion, le tableau de bord des jobs n'est pas lisible
    Quand j'ouvre le tableau de bord des jobs
    Alors on me demande de me connecter

  Scénario: un mot de passe incorrect n'ouvre pas l'espace
    Étant donné un compte d'administration
    Quand je me connecte avec un mot de passe incorrect
    Alors on me dit que les identifiants sont refusés

  Scénario: se déconnecter referme l'espace
    Étant donné un compte d'administration
    Et que je suis connecté à l'espace d'administration
    Quand je me déconnecte
    Et que j'ouvre la liste des conversations
    Alors on me demande de me connecter
