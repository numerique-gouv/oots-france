# language: fr
@bout_en_bout
Fonctionnalité: Demander le justificatif de la démarche de démonstration

  L'administrateur tient ici le rôle d'un étudiant danois qui demande une
  bourse. Une fois identifié, l'usager demande que son justificatif
  d'inscription soit récupéré auprès de l'administration qui le détient, voit
  qui le fournira et de quel type, puis confirme — et c'est cette confirmation
  qui envoie la requête.

  Ce que ces scénarios prouvent, et que la suite unitaire ne peut pas montrer :
  la démarche de démonstration appelle la France par la même adresse publique
  qu'un portail de démarche français, avec un jeton du bénéficiaire qu'elle
  signe et que la France ouvre en lisant les clés que la démarche publie. La
  chaîne entière se voit donc ici, du clic de l'usager jusqu'au message parti
  par la passerelle.

  Ils demandent une vraie passerelle Domibus, les vrais annuaires européens, le
  faux FranceConnect+ que la suite lance à côté d'elle, et le compte
  d'administration des données de démonstration. docs/test_e2e.md dit comment
  les jouer.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et l'administrateur de démonstration connecté à l'espace d'administration

  Scénario: l'usager demande son justificatif et la requête part pour de bon
    Quand l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Et que l'usager demande que son justificatif soit récupéré
    Alors la page de confirmation affiche le fournisseur et le type de justificatif
    Quand l'usager confirme sa demande
    Alors la page de suivi affiche l'identifiant de l'échange ouvert
    Et le journal des échanges contient le départ de la requête, envoyée par la démarche de démonstration
    Et cette requête contient l'identité que FranceConnect+ a donnée à la démarche
    Et cette requête déclare que l'usager a demandé le justificatif

  Scénario: sans demande de l'usager, aucune requête ne part
    Quand l'administrateur s'identifie avec l'identité de test "dk-substantial"
    Et que l'usager refuse que son justificatif soit récupéré
    Alors la démarche de démonstration affiche que le justificatif reste à fournir
    Et la France n'a envoyé aucune requête
