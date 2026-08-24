# language: fr
Fonctionnalité: Suivre les échanges depuis l'espace d'administration

  L'espace d'administration donne à voir ce que les échanges ont déjà écrit :
  le journal des évènements, où l'on cherche, et sous lui la fiche d'un échange
  et celle d'une conversation, où l'on descend. Il observe et n'écrit rien.

  Contexte:
    Étant donné un compte d'administration
    Et que je suis connecté à l'espace d'administration

  Scénario: le journal se restreint à un seul échange
    Étant donné un échange délivré avec la Finlande
    Et un échange en échec avec l'Allemagne
    Quand j'ouvre le journal des évènements
    Et que je filtre sur l'échange allemand
    Alors je vois les évènements de l'échange allemand
    Et je ne vois plus ceux de l'échange finlandais

  Scénario: la fiche d'un échange dit pourquoi il a échoué
    Étant donné un échange en échec avec l'Allemagne
    Quand j'ouvre la fiche de l'échange allemand
    Alors je lis le code d'erreur "EDM:ERR:0004"
    Et je lis la raison de l'échec de l'échange allemand

  Scénario: la conversation rassemble les échanges d'une même session
    Étant donné deux échanges d'un même usager
    Quand j'ouvre la conversation de cet usager
    Alors je vois les deux échanges, chacun avec son journal

  Scénario: le journal garde le refus qu'aucun échange ne porte
    Étant donné une requête refusée avant qu'aucun échange soit ouvert
    Quand j'ouvre le journal des évènements
    Alors je vois ce refus dans le journal
    Et il ne nomme ni échange ni conversation

  Scénario: un échange reçu tient sa fiche comme un échange émis
    Étant donné un échange reçu d'un autre État membre
    Quand j'ouvre la fiche de cet échange
    Alors je vois cet échange avec le sens "Reçu"

  Scénario: retrouver ce qui a circulé au sujet d'une personne
    Étant donné un échange concernant Sophie Dupont
    Quand je recherche la personne "Dupont" "Sophie" née le "1965-11-25"
    Alors je vois cet échange dans le journal
