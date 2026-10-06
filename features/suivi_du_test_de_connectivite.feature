# language: fr
@javascript
Fonctionnalité: Suivre sans recharger la page le test de connectivité d'un point d'accès

  L'administrateur teste un point d'accès depuis la page des points d'accès de l'espace d'administration. La page ne se recharge pas : le point d'accès passe « en cours », puis affiche son issue dès que la France l'a lue dans la passerelle.

  Ce scénario demande un navigateur sans tête, et rien de plus : la passerelle est doublée. docs/test_e2e.md le situe parmi les configurations de la suite.

  Contexte:
    Étant donné une passerelle doublée dont le PMode déclare le point d'accès "AP_EL_01"
    Et un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration

  Scénario: le point d'accès passe en cours puis affiche son issue sans que la page se recharge
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_EL_01"
    Alors le point d'accès "AP_EL_01" affiche "en cours", sans bouton de test
    Quand la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors le point d'accès "AP_EL_01" affiche "connecté", sans que la page se soit rechargée
