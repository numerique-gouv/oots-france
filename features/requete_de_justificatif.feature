# language: fr
@bout_en_bout
Fonctionnalité: Demander un justificatif à un autre État membre

  Ces scénarios traversent une vraie passerelle Domibus : la requête est
  construite, envoyée, transportée, reçue, traitée, et le justificatif revient
  jusqu'au portail de démarche. C'est ici, et ici seulement, qu'un PMode
  absent, un certificat expiré ou une enveloppe refusée se voient ; la suite
  unitaire simule tout ce transport.

  La France se répond à elle-même, sur l'unique passerelle du PMode d'exemple.
  Les annuaires centraux, eux, sont les vrais : la France est inscrite à
  l'acceptation, et chaque scénario y découvre l'exigence, le type de
  justificatif et le point d'accès. Un échec peut donc venir de l'acceptation
  plutôt que du dépôt ; docs/test_e2e.md dit comment faire la différence.

  Contexte:
    Étant donné un portail de démarche français déclaré dans l'annuaire des requêteurs
    Et que ce portail publie ses clés de signature

  Scénario: le justificatif revient du fournisseur jusqu'au portail
    Quand le portail demande un justificatif pour la démarche "00"
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et le portail reçoit le justificatif
    Et le justificatif reçu est le document que le fournisseur détient
    Et le journal des échanges contient tout l'échange, de l'envoi de la requête à la remise du justificatif
    Et le journal des échanges contient le corps RegRep de chaque message, tel qu'il a circulé

  Scénario: le justificatif de la démarche "T1" revient jusqu'au portail
    Quand le portail demande un justificatif pour la démarche "T1"
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et le portail reçoit le justificatif
    Et le justificatif reçu est le document que le fournisseur détient

  Scénario: deux demandes d'un même usager forment une seule conversation
    Quand le portail demande deux justificatifs pour le même usager
    Alors les deux requêtes ont la même conversation et deux échanges distincts

  Scénario: le fournisseur annonce le justificatif pour une date ultérieure
    Quand le portail demande un justificatif pour la démarche "R1"
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et l'échange passe à l'état "deferred"
    Et le portail apprend la date à laquelle le justificatif sera disponible
    Et le portail ne reçoit aucun justificatif
    Et le journal des échanges contient la réponse différée du fournisseur

  Scénario: le fournisseur ne connaît pas la démarche et répond une erreur
    Quand le portail demande un justificatif pour la démarche "T3"
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et l'échange passe au code d'erreur "EDM:ERR:0004"
    Et le portail ne reçoit aucun justificatif
    Et le journal des échanges contient l'erreur du fournisseur
    Et le journal des échanges contient le corps RegRep de chaque message, tel qu'il a circulé
