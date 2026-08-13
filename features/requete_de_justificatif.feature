# language: fr
@bout_en_bout
Fonctionnalité: Demander un justificatif à un autre État membre

  Ces deux scénarios traversent une vraie passerelle Domibus : requête
  construite, soumise au plugin WS, transportée en AS4, reçue, traitée, réponse
  renvoyée, justificatif retransmis à la démarche. La suite unitaire simule
  entièrement ce transport ; c'est ici, et ici seulement, qu'un PMode absent, un
  certificat expiré ou une enveloppe refusée se voient.

  L'échange boucle sur la seule passerelle du PMode d'exemple : l'application se
  répond donc à elle-même, sans dépendre d'un autre État membre pour le
  transport. Les annuaires centraux, eux, sont tenus par un double : la France
  n'y est pas inscrite, et l'attendre laisserait le transport sans filet. Ce que
  ce double ne couvre pas — la découverte DNS et la conformité des vraies
  réponses — est éprouvé par la suite unitaire, sur des réponses capturées.

  Contexte:
    Étant donné une démarche française déclarée dans l'annuaire
    Et que cette démarche publie ses clés de signature
    Et que les annuaires centraux désignent la passerelle locale

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
