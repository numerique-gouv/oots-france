# language: fr
@javascript
Fonctionnalité: Suivre sans recharger la page le test de connectivité d'un point d'accès, et sa place dans la liste

  L'administrateur teste un point d'accès depuis la page des points d'accès de l'espace d'administration. La page ne se recharge pas : le point d'accès passe « en cours », puis affiche son issue dès que la France l'a lue dans la passerelle. Les points d'accès se lisent connectés d'abord, puis en cours, puis les autres, et se reclassent à mesure que les tests partent et que leurs issues sont lues, sans que la page se recharge ; seuls les points d'accès dont l'issue a changé se déplacent.

  Ce scénario demande un navigateur sans tête, et rien de plus : la passerelle est doublée. docs/test_e2e.md le situe parmi les configurations de la suite.

  Contexte:
    Étant donné un administrateur connecté à l'espace d'administration

  Scénario: le point d'accès passe en cours puis affiche son issue sans que la page se recharge
    Étant donné une passerelle doublée dont le PMode déclare le point d'accès "AP_EL_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_EL_01"
    Alors le point d'accès "AP_EL_01" affiche "en cours", sans bouton de test
    Quand la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors le point d'accès "AP_EL_01" affiche "connecté", sans que la page se soit rechargée

  Scénario: un point d'accès mis en cours passe devant ceux qui n'ont jamais été testés
    Étant donné une passerelle doublée dont le PMode déclare les points d'accès "AP_AT_01", "AP_EL_01" et "AP_IT_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_IT_01"
    Alors le point d'accès "AP_IT_01" affiche "en cours", sans bouton de test
    Et le point d'accès "AP_IT_01" précède "AP_AT_01"
    Et la page ne s'est pas rechargée

  Scénario: les points d'accès se reclassent à mesure que leurs issues sont lues
    Étant donné une passerelle doublée dont le PMode déclare les points d'accès "AP_AT_01", "AP_EL_01" et "AP_IT_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste tous les points d'accès
    Alors les points d'accès se lisent "AP_AT_01", "AP_EL_01" et "AP_IT_01"
    Quand la France lit dans la passerelle que le point d'accès "AP_AT_01" est en échec
    Et que la France lit dans la passerelle que le point d'accès "AP_IT_01" a acquitté le test
    Alors les points d'accès se lisent "AP_IT_01", "AP_EL_01" et "AP_AT_01"
    Et le point d'accès "AP_IT_01" affiche "connecté", sans que la page se soit rechargée
    Et le point d'accès "AP_EL_01" affiche "en cours", sans bouton de test
    Et le point d'accès "AP_AT_01" affiche "en échec", sans que la page se soit rechargée
    Quand la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors les points d'accès se lisent "AP_EL_01", "AP_IT_01" et "AP_AT_01"

  Scénario: seul le point d'accès dont l'issue change se déplace, et il reste annoncé aux lecteurs d'écran
    Étant donné une passerelle doublée dont le PMode déclare les points d'accès "AP_AT_01" et "AP_EL_01"
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste tous les points d'accès
    Alors le point d'accès "AP_AT_01" affiche "en cours", sans bouton de test
    Et le point d'accès "AP_EL_01" affiche "en cours", sans bouton de test
    Quand une marque est posée sur le bloc du point d'accès "AP_AT_01"
    Et qu'une marque est posée sur le bloc du point d'accès "AP_EL_01"
    Et que la France lit dans la passerelle que le point d'accès "AP_EL_01" a acquitté le test
    Alors le point d'accès "AP_EL_01" précède "AP_AT_01"
    Et seul le bloc du point d'accès "AP_EL_01" s'est déplacé
    Et le bloc du point d'accès "AP_AT_01" porte encore la marque
    Et le bloc du point d'accès "AP_EL_01" porte encore la marque
    Et le bloc du point d'accès "AP_AT_01" porte "aria-busy" à "true"
    Et le bloc du point d'accès "AP_EL_01" porte "aria-live" à "polite", et plus "aria-busy"
    Et la page ne s'est pas rechargée
