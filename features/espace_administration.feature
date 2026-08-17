# language: fr
Fonctionnalité: Suivre les échanges depuis l'espace d'administration

  L'espace d'administration donne à voir ce que les échanges ont déjà écrit :
  l'état de chaque conversation et, pour celles qui ont échoué, la raison —
  qu'aucune autre interface n'expose. Il observe et n'écrit rien.

  Contexte:
    Étant donné un compte d'administration
    Et que je suis connecté à l'espace d'administration

  Scénario: la liste donne l'état de chaque conversation
    Étant donné une conversation délivrée avec la Finlande
    Et une conversation en échec avec l'Allemagne
    Quand j'ouvre la liste des conversations
    Alors je vois la conversation finlandaise avec l'état "Délivrée"
    Et je vois la conversation allemande avec l'état "Échec"

  Scénario: filtrer sur un état ne laisse que les conversations concernées
    Étant donné une conversation délivrée avec la Finlande
    Et une conversation en échec avec l'Allemagne
    Quand j'ouvre la liste des conversations
    Et que je filtre sur l'état "Échec"
    Alors je ne vois plus la conversation finlandaise
    Et je vois la conversation allemande avec l'état "Échec"

  Scénario: la fiche d'une conversation dit pourquoi l'échange a échoué
    Étant donné une conversation en échec avec l'Allemagne
    Quand j'ouvre la fiche de la conversation allemande
    Alors je lis le code d'erreur "EDM:ERR:0004"
    Et je lis la raison de l'échec de la conversation allemande
