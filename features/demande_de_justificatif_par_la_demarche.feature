# language: fr
@bout_en_bout
Fonctionnalité: Demander le justificatif de la démarche de démonstration

  L'administrateur tient ici le rôle d'un étudiant danois qui demande une bourse, dans la version OOTS qu'il a choisie en ouvrant la démarche : la requête part dans cette version. Une fois identifié, l'usager voit qui fournira son justificatif d'inscription et de quel type, puis confirme — et c'est cette confirmation qui demande le justificatif et envoie la requête. La démarche accepte que l'usager voie d'abord le document : il suit le lien que la démarche lui présente vers l'espace de prévisualisation du fournisseur, y choisit de l'utiliser ou non, et l'espace le ramène aussitôt à sa démarche par l'adresse de retour.

  Ce que ces scénarios prouvent, et que la suite unitaire ne peut pas montrer : la démarche de démonstration appelle la France par la même adresse publique qu'un portail de démarche français, avec un jeton du bénéficiaire qu'elle signe et que la France ouvre en lisant les clés que la démarche publie. La chaîne entière se voit donc ici, du clic de l'usager jusqu'au message parti par la passerelle, puis jusqu'au retour de l'usager et au justificatif qu'il a accepté. La France se répond à elle-même : l'espace visité est le sien.

  Ils demandent une vraie passerelle Domibus, les vrais annuaires européens, le faux FranceConnect+ et le faux ProConnect que la pile lance à côté d'elle. docs/test_e2e.md dit comment les jouer.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et l'administrateur de démonstration connecté à l'espace d'administration

  Scénario: l'usager demande son justificatif et la requête part pour de bon
    Quand l'administrateur choisit la version "OOTS 2.0"
    Et que l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Alors la page des justificatifs affiche le fournisseur et le type de justificatif
    Quand l'usager confirme sa demande
    Alors la page des justificatifs affiche que la demande de l'usager est en cours
    Et le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration
    Et cette requête contient l'identité que FranceConnect+ a donnée à la démarche
    Et cette requête déclare que l'usager a demandé le justificatif
    Et la fiche de cet échange affiche la version "oots-edm:v2.0"
    Quand l'usager suit le lien que la page des justificatifs lui présente vers l'espace de prévisualisation
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager est ramené à sa démarche
    Alors l'usager arrive sur la page des justificatifs, qui reçoit l'échange et la conversation
    Et la page des justificatifs affiche "Document retrieved successfully"

  Scénario: l'usager qui a choisi la version 1.2 demande son justificatif en 1.2
    Quand l'administrateur choisit la version "OOTS 1.2"
    Et que l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Alors la page des justificatifs affiche le fournisseur et le type de justificatif
    Quand l'usager confirme sa demande
    Alors la page des justificatifs affiche que la demande de l'usager est en cours
    Et le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration
    Et la fiche de cet échange affiche la version "oots-edm:v1.2"
    Quand l'usager suit le lien que la page des justificatifs lui présente vers l'espace de prévisualisation
    Alors ce lien contient l'adresse de retour dans "returnurl" et sa méthode dans "returnmethod"
    Quand l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager est ramené à sa démarche
    Alors l'usager arrive sur la page des justificatifs, qui reçoit l'échange et la conversation
    Et la page des justificatifs affiche "Document retrieved successfully"

  Scénario: l'usager refuse le document sur l'espace de prévisualisation, et la démarche le dit
    Quand l'administrateur choisit la version "OOTS 2.0"
    Et que l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Et que l'usager confirme sa demande
    Et que l'usager suit le lien que la page des justificatifs lui présente vers l'espace de prévisualisation
    Et que l'usager choisit "Ne pas l'utiliser" et valide son choix
    Et que l'usager est ramené à sa démarche
    Alors l'usager arrive sur la page des justificatifs, qui reçoit l'échange et la conversation
    Et la page des justificatifs affiche que l'usager a choisi de ne pas utiliser le document
