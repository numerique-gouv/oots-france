# language: fr
@javascript
Fonctionnalité: Demander entière, depuis la démarche de démonstration, une combinaison de types de justificatif

  Le pays d'une carte peut publier, pour son exigence, une combinaison de
  plusieurs types de justificatif, qui ne la satisfait qu'ensemble. La carte
  l'offre parmi les autres, nommée comme l'Evidence Broker la nomme ; une fois
  choisie, elle nomme le fournisseur de chacun de ses types, ligne par ligne,
  pose sur sa ligne la question que le Data Service Directory pose sur un type,
  et ne laisse rien partir tant qu'un type n'a pas son fournisseur. Un seul
  bouton demande alors tous les types, une demande chacun, sous la conversation
  du parcours, et la zone suit chaque demande dans son propre bloc.

  Ces scénarios demandent un navigateur sans tête, et rien de plus : ni
  passerelle, ni annuaire réel, ni FranceConnect+ réel. docs/test_e2e.md les
  situe parmi les configurations de la suite.

  Contexte:
    Étant donné les annuaires et le contrat de la démarche doublés
    Et un administrateur connecté à l'espace d'administration
    Et l'usager identifié sur la page des justificatifs

  Scénario: la carte offre chaque combinaison que le pays publie, dans l'ordre où il les écrit, nommée comme il la nomme
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte affiche "Select a document"
    Et la liste des combinaisons de la carte offre, dans l'ordre :
      | combinaison                |
      | Simple test evidence       |
      | Projectathon test evidence |
      | Compound test evidence     |

  Scénario: une combinaison sans nom se nomme de ses types, et ni une liste vide ni une liste répétée ne s'offrent
    Étant donné la Grèce publiant pour l'exigence de la carte les listes :
      | liste                                              |
      | Simple test evidence                               |
      | Compound test evidence, sans nom                   |
      | une liste "NoMatch"                                |
      | Compound test evidence, sous une autre juridiction |
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte offre, dans l'ordre :
      | combinaison                                         |
      | Simple test evidence                                |
      | Projectathon test evidence and Simple test evidence |

  Scénario: une combinaison seule n'offre pas de liste, et la carte nomme le fournisseur de chacun de ses types
    Étant donné la Grèce publiant pour l'exigence de la carte les listes :
      | liste                  |
      | Compound test evidence |
      | une liste "NoMatch"    |
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Alors la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Et la carte n'offre pas de liste des combinaisons
    Et la page affiche le bouton "Request the documents"

  Scénario: choisir une combinaison nomme chacun de ses types, et le bouton les demande tous, un par un, sous la même conversation
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Et la page affiche le bouton "Request the documents"
    Et la page des justificatifs n'a pas été rechargée
    Et le contrat n'a reçu aucune demande
    Quand l'usager choisit "Simple test evidence" dans la liste des combinaisons de la carte
    Alors la carte nomme, ligne par ligne :
      | type                 | fournisseur                    |
      | Simple test evidence | Ministry of Digital Governance |
    Et la page affiche le bouton "Request the document"
    Quand l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Request the documents"
    Alors le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
      | Simple test evidence       |
    Et la zone affiche un bloc par type, dans l'ordre :
      | type                       |
      | Projectathon test evidence |
      | Simple test evidence       |

  Scénario: un type qui pose une question la pose sur sa ligne, et rien ne part avant sa réponse
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la ligne de "Projectathon test evidence" pose la question "Projectathon test case"
    Et la carte pose la question "Projectathon test case" dans une liste ouverte sur "Select a value"
    Et la ligne de "Simple test evidence" affiche "Simple test evidence from Ministry of Digital Governance"
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Evidence impossible to satisfy"
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la ligne de "Projectathon test evidence" affiche "Projectathon test evidence from Ministry of Digital Governance"
    Et la page affiche le bouton "Request the documents"
    Et la page des justificatifs n'a pas été rechargée

  Scénario: un type sans fournisseur le dit sur sa ligne, et la carte n'offre aucun bouton sans être insatisfaisable
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et aucun fournisseur publié en Grèce pour "Simple test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la ligne de "Projectathon test evidence" affiche "Projectathon test evidence from Ministry of Digital Governance"
    Et la ligne de "Simple test evidence" affiche "No provider listed by Greece for this evidence"
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Evidence impossible to satisfy"

  Scénario: une demande refusée par le contrat arrête les suivantes, et chaque type garde son propre bouton
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et le contrat refusant la demande de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Request the documents"
    Alors le bloc de "Projectathon test evidence" affiche "EB:ERR:0001"
    Et le bloc de "Simple test evidence" affiche "Request the document"
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Quand l'usager clique sur "Retry to request" dans le bloc de "Projectathon test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "EB:ERR:0001"
    Et le bloc de "Projectathon test evidence" n'affiche pas "Requesting the document"
    Quand l'usager recharge la page des justificatifs
    Alors le bloc de "Projectathon test evidence" affiche "Request the document"
    Et le bloc de "Simple test evidence" affiche "Request the document"
    Quand l'usager clique sur "Request the document" dans le bloc de "Simple test evidence"
    Alors le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
      | Projectathon test evidence |
      | Simple test evidence       |

  Scénario: le refus d'une demande reste dit pendant que la demande acceptée avant elle attend
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et le contrat refusant la demande de "Simple test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Request the documents"
    Alors le bloc de "Simple test evidence" affiche "EB:ERR:0001"
    Quand la zone a interrogé deux fois de plus son adresse
    Alors le bloc de "Simple test evidence" affiche "EB:ERR:0001"
    Et le bloc de "Projectathon test evidence" affiche "Requesting the document"

  Scénario: la combinaison tient au rechargement, une demande la retient, et un autre pays la défait
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la page affiche le bouton "Request the documents"
    Quand l'usager recharge la page des justificatifs
    Alors la liste des combinaisons de la carte affiche "Compound test evidence"
    Et la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Quand l'usager clique sur "Request the documents"
    Alors la zone affiche un bloc par type, dans l'ordre :
      | type                       |
      | Projectathon test evidence |
      | Simple test evidence       |
    Quand l'usager recharge la page des justificatifs
    Alors la carte n'offre pas de liste des pays
    Et la carte n'offre pas de liste des combinaisons
    Et la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Quand chaque demande de la combinaison est refusée
    Et que l'usager recharge la page des justificatifs
    Alors la liste des combinaisons de la carte affiche "Compound test evidence"
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la carte n'offre pas de liste des combinaisons
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte affiche "Select a document"

  Scénario: un type qui reçoit une réponse différée la dit dans son bloc pendant que l'autre attend, et la carte offre ses listes une fois chacun différé
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Request the documents"
    Et que le fournisseur répond à la demande de "Projectathon test evidence" par une réponse différée
    Alors le bloc de "Projectathon test evidence" affiche "Document announced for later"
    Quand la zone a interrogé deux fois de plus son adresse
    Alors le bloc de "Projectathon test evidence" affiche "Document announced for later"
    Et le bloc de "Simple test evidence" affiche "Requesting the document"
    Quand le fournisseur répond à la demande de "Simple test evidence" par une réponse différée
    Et que l'usager recharge la page des justificatifs
    Alors la liste des combinaisons de la carte affiche "Compound test evidence"
    Et la page affiche le bouton "Retry to request"
