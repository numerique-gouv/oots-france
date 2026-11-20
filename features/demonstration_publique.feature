# language: fr
@bout_en_bout
Fonctionnalité: Jouer la démarche de démonstration depuis le site public, sans connexion

  Un visiteur du site public — une administration française, un homologue européen — tient ici le rôle d'un usager danois de la démarche de démonstration, sans aucune session de l'espace d'administration : il la trouve dans le menu du site, choisit la version OOTS et la démarche "00", s'identifie auprès du faux FranceConnect+, demande son justificatif et le reçoit. Les écrans sont ceux de la démarche de l'espace d'administration ; la requête part sous un requêteur propre à la démonstration publique.

  Ils demandent une vraie passerelle Domibus, les vrais annuaires européens et le faux FranceConnect+ que la pile lance à côté d'elle. docs/test_e2e.md dit comment les jouer.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et un visiteur sans session de l'espace d'administration

  Scénario: le visiteur demande son justificatif en version 2.0 et le reçoit
    Quand le visiteur ouvre la démarche de démonstration depuis la page d'accueil du site
    Alors le visiteur arrive sur l'écran du choix de la version, sous le bandeau de démonstration
    Quand le visiteur choisit la version "OOTS 2.0"
    Et que le visiteur choisit la démarche "00"
    Et que le visiteur s'identifie avec l'identité de test "dk-substantial"
    Alors le visiteur arrive sur la page des justificatifs
    Et la page des justificatifs affiche le fournisseur et le type de justificatif de la carte "(TEST) Test Requirement 2"
    Quand l'usager confirme la demande de la carte "(TEST) Test Requirement 2"
    Alors le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration publique
    Et cette requête nomme le requêteur "Démonstration publique d'OOTS-France"
    Quand l'usager suit le lien que la page des justificatifs lui présente vers l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager est ramené à sa démarche
    Alors l'usager arrive sur la page des justificatifs, qui reçoit l'échange et la conversation
    Et la page des justificatifs affiche "Document récupéré avec succès"

  Scénario: le visiteur demande son justificatif en version 1.2 et le reçoit
    Quand le visiteur choisit la version "OOTS 1.2"
    Et que le visiteur choisit la démarche "00"
    Et que le visiteur s'identifie avec l'identité de test "dk-substantial"
    Alors le visiteur arrive sur la page des justificatifs
    Quand l'usager confirme la demande de la carte "(TEST) Test Requirement 2"
    Alors le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration publique
    Quand l'usager suit le lien que la page des justificatifs lui présente vers l'espace de prévisualisation
    Et que l'usager s'identifie sur l'espace de prévisualisation avec l'identité de test "dk-substantial"
    Et que l'usager choisit "Utiliser ce document dans ma démarche" et valide son choix
    Et que l'usager est ramené à sa démarche
    Alors la page des justificatifs affiche "Document récupéré avec succès"

  Scénario: le visiteur saisit une identité à la main et la retrouve sur la page des justificatifs
    Quand le visiteur choisit la version "OOTS 2.0"
    Et que le visiteur choisit la démarche "00"
    Et que le visiteur s'identifie en saisissant cette identité sous le pays "PL":
      | prénom            | Alicja      |
      | nom               | Roszponka   |
      | date de naissance | 1991-04-06  |
      | identifiant eIDAS | 91040665144 |
    Alors le visiteur arrive sur la page des justificatifs
    Et la carte d'identité de la page des justificatifs affiche l'identifiant eIDAS "PL/FR/91040665144"
    Et la page affiche "Nom" : "Roszponka"
