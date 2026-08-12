# language: fr
@bout_en_bout @attente_inscription_fr
Fonctionnalité: Demander un justificatif à un autre État membre

  Ces deux scénarios traversent une vraie passerelle Domibus : requête
  construite, soumise au plugin WS, transportée en AS4, reçue, traitée, réponse
  renvoyée, justificatif retransmis à la démarche. La suite unitaire simule
  entièrement ce transport ; c'est ici, et ici seulement, qu'un PMode absent, un
  certificat expiré ou une enveloppe refusée se voient.

  L'échange boucle sur la seule passerelle du PMode d'exemple : l'application se
  répond donc à elle-même, sans dépendre d'un autre État membre pour le
  transport. Il dépend en revanche des annuaires centraux pour savoir à qui
  s'adresser, et c'est ce qui met aujourd'hui ces scénarios en attente : la
  France n'est inscrite ni au Data Service Directory, ni — pour la démarche du
  scénario d'erreur — à l'Evidence Broker. La requête est donc refusée avant
  d'atteindre la passerelle, et ces scénarios ne prouveraient plus rien du
  transport qu'ils existent pour couvrir.

  L'étiquette `@attente_inscription_fr` les écarte de `make e2e` en attendant ;
  docs/test_e2e.md dit ce qui doit être inscrit pour la retirer.

  Contexte:
    Étant donné une démarche française déclarée dans l'annuaire
    Et que cette démarche publie ses clés de signature

  Scénario: le justificatif revient du fournisseur et parvient à la démarche
    Quand la démarche demande un justificatif pour la procédure "00"
    Alors la démarche reçoit tout de suite l'identifiant de l'échange
    Et le justificatif finit par être transmis à la démarche
    Et le document reçu est celui que le fournisseur détient

  Scénario: le fournisseur ne connaît pas la démarche et le dit
    Quand la démarche demande un justificatif pour la procédure "T3"
    Alors la démarche reçoit tout de suite l'identifiant de l'échange
    Et la conversation finit par porter le code d'erreur "EDM:ERR:0004"
    Et aucun justificatif n'est transmis à la démarche
