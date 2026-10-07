# language: fr
Fonctionnalité: Se connecter à l'espace d'administration

  L'espace d'administration est réservé aux agents dont l'adresse est dans un domaine admis, qui s'identifient par ProConnect. Chacune de ses pages demande à l'administrateur de se connecter, y compris le tableau de bord des jobs. Les scénarios jouent ProConnect eux-mêmes et ne sortent pas vers le réseau : docs/test_e2e.md dit comment.

  Scénario: sans connexion, le journal des événements n'est pas lisible
    Étant donné un échange en échec avec l'Allemagne
    Quand un visiteur ouvre le journal des événements
    Alors la page de connexion propose de s'identifier avec ProConnect aux adresses en "@numerique.gouv.fr"
    Et la page n'affiche pas l'échange allemand

  Scénario: sans connexion, le tableau de bord des jobs n'est pas lisible
    Quand un visiteur ouvre le tableau de bord des jobs
    Alors la page de connexion propose de s'identifier avec ProConnect aux adresses en "@numerique.gouv.fr"

  Scénario: une adresse hors des domaines admis n'ouvre pas l'espace d'administration
    Quand un agent s'identifie par ProConnect avec l'adresse "agent@exemple.fr"
    Alors la page de connexion dit que l'adresse "agent@exemple.fr" n'est pas admise
    Quand il ouvre le journal des événements
    Alors la page de connexion s'affiche

  Scénario: une identification que ProConnect refuse n'ouvre pas l'espace d'administration
    Étant donné que ProConnect refuse la prochaine identification
    Quand l'administrateur s'identifie par ProConnect
    Alors la page de connexion dit "La connexion par ProConnect n'a pas abouti. Réessayez."

  Scénario: se déconnecter ferme l'espace d'administration
    Étant donné un administrateur connecté à l'espace d'administration
    Quand l'administrateur se déconnecte
    Alors la page de connexion dit "Vous êtes déconnecté."
    Quand il ouvre le journal des événements
    Alors la page de connexion s'affiche
