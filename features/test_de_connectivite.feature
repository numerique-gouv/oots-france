# language: fr
@bout_en_bout
Fonctionnalité: Tester depuis l'espace d'administration la connectivité avec un point d'accès

  L'administrateur lance depuis l'espace d'administration un test de connectivité vers un point d'accès du PMode chargé dans la passerelle, et lit son issue en rouvrant la page. Sur la pile locale, la passerelle ne déclare que le point d'accès de la France, qui se répond à lui-même. Le scénario demande une vraie passerelle et l'administrateur de démonstration : docs/test_e2e.md dit comment les obtenir.

  Scénario: le point d'accès de la France acquitte le test de connectivité
    Étant donné l'administrateur de démonstration connecté à l'espace d'administration
    Quand l'administrateur ouvre la page des points d'accès
    Et qu'il teste le point d'accès "AP_FR_01"
    Alors la page des points d'accès affiche "connecté" pour "AP_FR_01"
