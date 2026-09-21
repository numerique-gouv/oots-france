# language: fr
@javascript
Fonctionnalité: Lire à l'écran la raison d'un refus de FranceConnect+

  Quand FranceConnect+ refuse un échange de la démarche de démonstration, il dit
  pourquoi dans sa réponse. L'accueil de la démarche montre cette raison telle
  qu'elle est reçue : il n'invente pas les champs que FranceConnect+ n'a pas
  répondus, et il n'ajoute pas de point derrière une phrase qui porte déjà le
  sien. C'est ce qui fait que le raccordement au bac à sable puis à la
  production se diagnostique en une lecture.

  Ces scénarios demandent un navigateur sans tête, et rien de plus : ni
  passerelle, ni annuaire réel, ni FranceConnect+ réel. docs/test_e2e.md les
  situe parmi les configurations de la suite.

  Contexte:
    Étant donné les annuaires et le contrat de la démarche doublés
    Et un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration

  Scénario: l'accueil de la démarche nomme le refus que FranceConnect+ a répondu
    Étant donné FranceConnect+ qui refuse l'échange du code par "invalid_grant"
    Quand l'administrateur s'identifie depuis le bouton du faux FranceConnect+
    Alors la page affiche "invalid_grant"
    Et la page affiche le refus sans libellé vide ni point doublé

  Scénario: un retour qu'aucune identification n'a demandé est refusé d'une seule phrase
    Quand l'administrateur revient de FranceConnect+ sur une identification que ce navigateur n'a pas demandée
    Alors la page affiche "Ce retour ne correspond à aucune identification demandée depuis ce navigateur."
    Et la page affiche le refus sans libellé vide ni point doublé
