# language: fr
@bout_en_bout
Fonctionnalité: Demander un justificatif que l'usager voit d'abord chez le fournisseur

  Le portail demande un justificatif en acceptant que l'usager le voie
  d'abord. Le fournisseur répond l'adresse de son espace de prévisualisation ;
  le portail confirme, la France émet la seconde requête, l'usager consulte le
  document, choisit, et l'espace le ramène au portail par l'adresse de retour
  de la France. Le portail reçoit ce que l'usager a accepté, et rien s'il a refusé.

  La France se répond à elle-même sur l'unique passerelle du PMode d'exemple :
  elle y tient le fournisseur et son espace autant que le requêteur. L'usager
  suit les liens dans un navigateur. docs/test_e2e.md dit ce que ces scénarios
  demandent pour tourner.

  Contexte:
    Étant donné un portail de démarche français déclaré dans l'annuaire des requêteurs
    Et que ce portail publie ses clés de signature

  Scénario: l'usager accepte le document, et le portail le reçoit
    Quand le portail demande un justificatif pour la démarche "T1" en acceptant que l'usager le voie d'abord
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et l'échange passe à l'état "preview_required"
    Et le portail lit l'adresse de l'espace de prévisualisation et sa description
    Quand le portail confirme la prévisualisation avec son jeton et l'adresse où reprendre la démarche
    Alors le portail reçoit le lien à présenter à l'usager
    Et l'échange passe à l'état "sent"
    Quand l'usager ouvre l'espace de prévisualisation par le lien que le portail lui présente
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager est ramené au portail
    Alors l'usager arrive sur la page du portail, qui reçoit l'échange et la conversation
    Et le portail reçoit le justificatif
    Et l'échange passe à l'état "delivered"
    Et le journal des échanges contient la seconde requête et le retour de l'usager

  Scénario: l'usager refuse le document, et le portail ne reçoit rien
    Quand le portail demande un justificatif pour la démarche "T1" en acceptant que l'usager le voie d'abord
    Alors le portail reçoit tout de suite l'identifiant de l'échange
    Et l'échange passe à l'état "preview_required"
    Quand le portail confirme la prévisualisation avec son jeton et l'adresse où reprendre la démarche
    Et que l'usager ouvre l'espace de prévisualisation par le lien que le portail lui présente
    Et que l'usager choisit "Ne pas l'utiliser" et valide son choix
    Et que l'usager est ramené au portail
    Alors l'usager arrive sur la page du portail, qui reçoit l'échange et la conversation
    Et l'échange passe à l'état "declined"
    Et le portail ne reçoit aucun justificatif
