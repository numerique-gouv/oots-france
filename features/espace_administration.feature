# language: fr
Fonctionnalité: Suivre les échanges depuis l'espace d'administration

  L'espace d'administration affiche ce que les échanges ont écrit dans le
  journal des événements. L'administrateur y cherche un événement, puis ouvre
  la fiche de l'échange ou de la conversation concernés. Il n'y modifie
  rien.

  La démarche de démonstration est la seule exception : l'administrateur y
  tient le rôle de l'usager d'un portail de démarche.

  Contexte:
    Étant donné un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration

  Scénario: filtrer le journal des événements sur un seul échange
    Étant donné un échange délivré avec la Finlande
    Et un échange en échec avec l'Allemagne
    Quand l'administrateur ouvre le journal des événements
    Et qu'il filtre sur l'échange allemand
    Alors le journal affiche les événements de l'échange allemand
    Et le journal n'affiche pas les événements de l'échange finlandais

  Scénario: la fiche d'un échange en échec affiche la raison de l'échec
    Étant donné un échange en échec avec l'Allemagne
    Quand l'administrateur ouvre la fiche de l'échange allemand
    Alors la fiche affiche le code d'erreur "EDM:ERR:0004"
    Et la fiche affiche la raison de l'échec de l'échange allemand

  Scénario: la fiche d'une conversation affiche tous les échanges de l'usager
    Étant donné deux échanges d'un même usager
    Quand l'administrateur ouvre la fiche de cette conversation
    Alors la fiche affiche les deux échanges, chacun avec ses événements

  Scénario: le journal des événements garde une requête refusée avant tout échange
    Étant donné une requête refusée avant qu'aucun échange soit ouvert
    Quand l'administrateur ouvre le journal des événements
    Alors le journal affiche ce refus
    Et le refus ne nomme ni échange ni conversation

  Scénario: un échange reçu a une fiche, comme un échange émis
    Étant donné un échange reçu d'un autre État membre
    Quand l'administrateur ouvre la fiche de cet échange
    Alors la fiche affiche le sens "Reçu"

  Scénario: la démarche de démonstration s'ouvre depuis le menu
    Quand l'administrateur suit l'entrée « Démo » du menu
    Alors la page d'accueil de la démarche de démonstration s'affiche
    Et la page propose de s'identifier avec une identité d'un autre État membre

  Scénario: retrouver les échanges qui concernent une personne
    Étant donné un échange concernant Sophie Dupont
    Quand l'administrateur recherche la personne "Dupont" "Sophie" née le "1965-11-25"
    Alors le journal affiche cet échange
