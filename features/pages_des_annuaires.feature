# language: fr
@javascript
Fonctionnalité: Consulter les pages des annuaires centraux dans un navigateur

  Deux pages de la console ne sont pas servies d'un bloc : elles arrivent avec
  leur titre et une zone d'attente, puis vont chercher leur liste. Et partout où
  une liste est longue, un champ de recherche la restreint dans le navigateur,
  sans repasser par le serveur. Ce que ces scénarios éprouvent est donc ce que
  le navigateur décide, et aucun d'eux ne prouve quoi que ce soit joué sans lui.

  Ils demandent un navigateur sans tête, et rien de plus : ni passerelle, ni
  annuaire réel. Par quelle commande ils se jouent et comment installer ce
  qu'elle demande est au README ; docs/test_e2e.md les situe parmi les
  configurations de la suite.

  Contexte:
    Étant donné un Evidence Broker qui publie le catalogue des exigences
    Et un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration

  Scénario: la liste des exigences arrive après la page, sous une zone d'attente
    Étant donné que le contenu de la page des exigences est retenu
    Quand l'administrateur ouvre la page des exigences
    Alors la zone d'attente annonce "Chargement de toutes les exigences publiées, veuillez patienter."
    Et son tourniquet est affiché
    Quand le contenu est servi
    Alors la page affiche la liste des exigences, son décompte et son champ de recherche
    Et le décompte dit "53 résultats"
    Et la zone d'attente a disparu

  Scénario: un annuaire injoignable prend la place de la zone d'attente
    Étant donné un Evidence Broker qui ne répond pas
    Quand l'administrateur ouvre la page des exigences
    Alors la page affiche l'alerte "Annuaire injoignable"
    Et la zone d'attente a disparu
    Et la page n'affiche pas "Le contenu de cette page n'a pas pu être chargé."

  Scénario: une réponse que l'application n'a pas écrite n'est pas injectée
    Étant donné qu'une réponse sans l'en-tête "Deferred-Fragment" est fabriquée devant le navigateur
    Quand l'administrateur ouvre la page des exigences
    Alors la page n'affiche rien de cette réponse
    Et la zone d'attente annonce "Le contenu de cette page n'a pas pu être chargé. Rechargez la page pour réessayer."
    Et son tourniquet n'est plus affiché

  Scénario: une requête du contenu qui n'obtient aucune réponse échoue de même
    Étant donné que la connexion est coupée avant que le contenu soit servi
    Quand l'administrateur ouvre la page des exigences
    Alors la zone d'attente annonce "Le contenu de cette page n'a pas pu être chargé. Rechargez la page pour réessayer."
    Et son tourniquet n'est plus affiché

  Scénario: la recherche restreint la liste, quelles que soient la casse et les accents
    Étant donné la liste des exigences affichée
    Quand l'administrateur cherche "publiés nationalit"
    Alors seule l'exigence "Proof of nationality" reste affichée
    Et le décompte dit "Un résultat"
    Quand il cherche "PUBLIES NATIONALIT"
    Alors seule l'exigence "Proof of nationality" reste affichée
    Et le décompte dit "Un résultat"

  Scénario: une recherche qui ne correspond à aucune exigence le dit
    Étant donné la liste des exigences affichée
    Quand l'administrateur cherche "ES"
    Alors la page affiche "Aucune exigence ne correspond à cette recherche."
    Et le décompte dit "Aucun résultat"
    Quand il efface sa recherche
    Alors la page n'affiche pas "Aucune exigence ne correspond à cette recherche."

  Scénario: une carte affichée qui ne pèse rien n'est pas un écran vide
    Étant donné une exigence dont le seul pays fournisseur déclare ne délivrer aucun justificatif
    Quand l'administrateur ouvre la page de cette exigence
    Alors la carte du pays est affichée
    Et le décompte dit "Aucun résultat"
    Et la page n'affiche pas "Aucun type de justificatif ne correspond à cette recherche."
    Quand il cherche "naissance"
    Alors la carte du pays n'est plus affichée
    Et la page affiche "Aucun type de justificatif ne correspond à cette recherche."
    Quand il cherche "(FR)"
    Alors la carte du pays est affichée
    Et la page n'affiche pas "Aucun type de justificatif ne correspond à cette recherche."

  Scénario: une session finie pendant l'attente mène à la connexion, puis à la page entière
    Étant donné que le contenu de la page des exigences est retenu
    Quand l'administrateur ouvre la page des exigences
    Et que son compte est supprimé
    Et que le contenu est servi
    Alors la page de connexion s'affiche
    Et la page n'affiche pas "Le contenu de cette page n'a pas pu être chargé."
    Quand un autre administrateur se connecte
    Alors la page des exigences s'affiche entière, avec son titre et sa liste
