# language: fr
Fonctionnalité: Se connecter à l'espace d'administration

  L'espace d'administration est réservé aux agents dont l'adresse est dans un domaine admis, qui s'identifient par ProConnect. Chacune de ses pages demande à l'agent de se connecter, y compris le tableau de bord des jobs. Tout agent connecté lit les annuaires et joue la démarche de démonstration ; le journal des événements, le tableau de bord des jobs et les points d'accès sont réservés aux administrateurs que l'équipe qui exploite le service a nommés. Les scénarios jouent ProConnect eux-mêmes et ne sortent pas vers le réseau : docs/test_e2e.md dit comment.

  Scénario: sans connexion, le journal des événements n'est pas lisible
    Étant donné un échange en échec avec l'Allemagne
    Quand un visiteur ouvre le journal des événements
    Alors la page de connexion propose de s'identifier avec ProConnect
    Et la page n'affiche pas l'échange allemand

  Scénario: sans connexion, le tableau de bord des jobs n'est pas lisible
    Quand un visiteur ouvre le tableau de bord des jobs
    Alors la page de connexion propose de s'identifier avec ProConnect

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

  Scénario: un agent que personne n'a nommé administrateur ne se voit offrir que les annuaires et la démarche
    Étant donné un agent connecté à l'espace d'administration
    Quand l'agent ouvre l'accueil de l'espace d'administration
    Alors la page offre les tuiles "Annuaires centraux et Démarche de démonstration"
    Et l'en-tête offre les liens "Annuaires et Démo" seulement
    Quand l'agent ouvre l'accueil des annuaires
    Alors la page n'offre pas la carte des points d'accès
    Quand l'agent ouvre l'écran du choix de la version de la démarche
    Alors l'écran du choix de la version affiche les cartes "OOTS 2.0" puis "OOTS 1.2"

  Plan du scénario: un agent que personne n'a nommé administrateur est refusé sur <page>
    Étant donné un échange en échec avec l'Allemagne
    Et un agent connecté à l'espace d'administration
    Quand l'agent ouvre "<page>" par son adresse
    Alors la page dit qu'elle est réservée aux administrateurs nommés
    Et la page n'affiche pas l'échange allemand

    Exemples:
      | page                           |
      | le journal des événements      |
      | la fiche de l'échange allemand |
      | la recherche par personne      |
      | le tableau de bord des jobs    |
      | la page des points d'accès     |

  Scénario: un agent que personne n'a nommé administrateur ne lance pas de test de connectivité
    Étant donné un agent connecté à l'espace d'administration
    Quand l'agent demande un test de connectivité par son adresse
    Alors la page dit qu'elle est réservée aux administrateurs nommés
    Et aucun test de connectivité n'est enregistré

  Scénario: un agent nommé administrateur en cours de session lit le journal sans se reconnecter
    Étant donné un agent connecté à l'espace d'administration
    Quand son adresse est nommée administrateur
    Et que l'agent ouvre le journal des événements
    Alors le journal des événements s'affiche
    Et l'en-tête offre les liens "Annuaires, Journal, Jobs et Démo" seulement
    Quand l'agent ouvre l'accueil des annuaires
    Alors la page offre la carte des points d'accès
