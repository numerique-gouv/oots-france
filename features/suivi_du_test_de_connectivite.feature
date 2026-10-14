# language: fr
@javascript
Fonctionnalité: Suivre sans recharger la page le test de connectivité d'un point d'accès, et sa place dans la liste

  L'administrateur teste un point d'accès depuis la page des points d'accès de l'espace d'administration. La page ne se recharge pas : le point d'accès passe « en cours », puis affiche son issue dès que la France l'a lue dans la passerelle. Un point d'accès devenu connecté pendant le test garde sa place jusqu'à ce que la page soit rouverte, où il vient en tête.

  Ce scénario demande un navigateur sans tête, et rien de plus : la passerelle est doublée. docs/test_e2e.md le situe parmi les configurations de la suite.

  Contexte:
    Étant donné un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration

  Scénario: le point d'accès passe en cours puis affiche son issue sans que la page se recharge
    Étant donné une passerelle doublée dont le PMode déclare le point d'accès "AP_EL_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_EL_01"
    Alors le point d'accès "AP_EL_01" affiche "en cours", sans bouton de test
    Quand la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors le point d'accès "AP_EL_01" affiche "connecté", sans que la page se soit rechargée

  Scénario: un point d'accès connecté pendant le test garde sa place, et vient en tête quand la page est rouverte
    Étant donné une passerelle doublée dont le PMode déclare les points d'accès "AP_AT_01" et "AP_EL_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_EL_01"
    Et que la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors le point d'accès "AP_EL_01" affiche "connecté", sans que la page se soit rechargée
    Et le point d'accès "AP_AT_01" précède "AP_EL_01"
    Quand l'administrateur rouvre la page des points d'accès
    Alors le point d'accès "AP_EL_01" précède "AP_AT_01"
