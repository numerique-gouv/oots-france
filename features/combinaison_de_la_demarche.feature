# language: fr
@javascript
Fonctionnalité: Demander entière, depuis la démarche de démonstration, une combinaison de types de justificatif

  Le pays d'une carte peut publier, pour son exigence, une combinaison de
  plusieurs types de justificatif, qui ne la satisfait qu'ensemble. La carte
  l'offre parmi les autres, nommée comme l'Evidence Broker la nomme ; une fois
  choisie, elle nomme le fournisseur de chacun de ses types, ligne par ligne,
  pose sur sa ligne la question que le Data Service Directory pose sur un type,
  et ne laisse rien partir tant qu'un type n'a pas son fournisseur. La zone
  montre alors un bloc par type, dans l'ordre de la combinaison, et l'usager
  demande ses documents l'un après l'autre, sous la conversation du parcours :
  chacun d'un clic, et le suivant une fois le précédent récupéré, de sorte que
  la carte ne présente jamais plus d'un lien vers un espace de
  prévisualisation. Un document qui n'arrive pas arrête la séquence sur lui.

  Ces scénarios demandent un navigateur sans tête, et rien de plus : ni
  passerelle, ni annuaire réel, ni FranceConnect+ réel. docs/test_e2e.md les
  situe parmi les configurations de la suite.

  Contexte:
    Étant donné les annuaires et le contrat de la démarche doublés
    Et un administrateur connecté à l'espace d'administration
    Et l'usager identifié sur la page des justificatifs

  Scénario: la carte offre chaque combinaison que le pays publie, dans l'ordre où il les écrit, nommée comme il la nomme
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte affiche "Sélectionnez un document"
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
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte offre, dans l'ordre :
      | combinaison                                         |
      | Simple test evidence                                |
      | Projectathon test evidence et Simple test evidence |

  Scénario: une combinaison seule n'offre pas de liste, et la carte nomme le fournisseur de chacun de ses types
    Étant donné la Grèce publiant pour l'exigence de la carte les listes :
      | liste                  |
      | Compound test evidence |
      | une liste "NoMatch"    |
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Alors la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Et la carte n'offre pas de liste des combinaisons
    Et la zone affiche, dans l'ordre :
      | rang             | type                       | état                                                 |
      | Document 1 sur 2 | Projectathon test evidence | Demander le document                                 |
      | Document 2 sur 2 | Simple test evidence       | Sera demandé une fois le document précédent récupéré |

  Scénario: choisir une combinaison montre un bloc par document, et seul le premier se demande
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Et la zone affiche, dans l'ordre :
      | rang             | type                       | état                                                 |
      | Document 1 sur 2 | Projectathon test evidence | Demander le document                                 |
      | Document 2 sur 2 | Simple test evidence       | Sera demandé une fois le document précédent récupéré |
    Et le bloc de "Simple test evidence" n'offre aucun bouton
    Et la page n'affiche pas "Demander les documents"
    Et la page des justificatifs n'a pas été rechargée
    Et le contrat n'a reçu aucune demande
    Quand l'usager choisit "Simple test evidence" dans la liste des combinaisons de la carte
    Alors la carte nomme, ligne par ligne :
      | type                 | fournisseur                    |
      | Simple test evidence | Ministry of Digital Governance |
    Et la page affiche le bouton "Demander le document"
    Et la zone n'affiche ni rang ni attente d'un document précédent
    Quand l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Et que la zone a interrogé deux fois de plus son adresse
    Alors le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
    Et le bloc de "Projectathon test evidence" affiche "Demande du document en cours"
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Et le bloc de "Simple test evidence" n'offre aucun bouton

  Scénario: un type qui pose une question la pose sur sa ligne, et rien ne part avant sa réponse
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la ligne de "Projectathon test evidence" pose la question "Projectathon test case"
    Et la carte pose la question "Projectathon test case" dans une liste ouverte sur "Sélectionnez une valeur"
    Et la ligne de "Simple test evidence" affiche "Simple test evidence auprès de Ministry of Digital Governance"
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Justificatif impossible à fournir"
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la ligne de "Projectathon test evidence" affiche "Projectathon test evidence auprès de Ministry of Digital Governance"
    Et le bloc de "Projectathon test evidence" affiche "Demander le document"
    Et la page des justificatifs n'a pas été rechargée

  Scénario: un type sans fournisseur le dit sur sa ligne, et la carte n'offre aucun bouton sans être insatisfaisable
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et aucun fournisseur publié en Grèce pour "Simple test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors la ligne de "Projectathon test evidence" affiche "Projectathon test evidence auprès de Ministry of Digital Governance"
    Et la ligne de "Simple test evidence" affiche "Grèce ne déclare aucun fournisseur pour ce justificatif"
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Justificatif impossible à fournir"

  Scénario: la carte ne présente qu'un lien de prévisualisation à la fois, et le document suivant se demande une fois le précédent récupéré
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et le fournisseur demandant une prévisualisation pour chaque document de la combinaison
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "Prévisualiser et approuver le document"
    Et la carte présente un seul lien vers un espace de prévisualisation
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Quand l'usager recharge la page des justificatifs
    Alors le bloc de "Projectathon test evidence" affiche "Prévisualiser et approuver le document"
    Et la carte présente un seul lien vers un espace de prévisualisation
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Quand l'espace de prévisualisation ramène l'usager par l'adresse de retour de la demande de "Projectathon test evidence"
    Alors la page des justificatifs s'affiche positionnée sur la carte
    Et le bloc de "Projectathon test evidence" affiche "Demande du document en cours"
    Et la carte ne présente aucun lien vers un espace de prévisualisation
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Quand le justificatif de "Projectathon test evidence" est remis
    Alors le bloc de "Projectathon test evidence" affiche "Document récupéré avec succès"
    Et le bloc de "Projectathon test evidence" affiche "Ouvrir le document"
    Et le bloc de "Simple test evidence" affiche "Demander le document"
    Et la page des justificatifs n'a pas été rechargée
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Et la carte n'offre pas de liste des combinaisons
    Quand l'usager recharge la page des justificatifs
    Alors le bloc de "Simple test evidence" affiche "Demander le document"
    Quand l'usager clique sur "Demander le document" dans le bloc de "Simple test evidence"
    Alors le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
      | Simple test evidence       |
    Et le bloc de "Simple test evidence" affiche "Prévisualiser et approuver le document"
    Et la carte présente un seul lien vers un espace de prévisualisation

  Scénario: un document écarté sur l'espace de prévisualisation arrête la séquence sur lui, et la carte offre de nouveau ses listes
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Et que l'usager écarte le document de "Projectathon test evidence" sur l'espace de prévisualisation
    Alors le bloc de "Projectathon test evidence" affiche "Aucun document n'a été envoyé à cette démarche"
    Et le bloc de "Projectathon test evidence" affiche "Redemander le document"
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Et le bloc de "Simple test evidence" n'offre aucun bouton
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Et la liste des combinaisons de la carte est active

  Scénario: une demande refusée par le contrat le dit dans son bloc, qui garde son bouton, et le document suivant attend toujours
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Et le contrat refusant la demande de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "EB:ERR:0001"
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Et le bloc de "Simple test evidence" n'offre aucun bouton
    Et le contrat n'a reçu de demande que pour "Projectathon test evidence"
    Et la liste des combinaisons de la carte est active
    Quand l'usager clique sur "Redemander le document" dans le bloc de "Projectathon test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "EB:ERR:0001"
    Et le bloc de "Projectathon test evidence" n'affiche pas "Demande du document en cours"
    Quand l'usager recharge la page des justificatifs
    Alors le bloc de "Projectathon test evidence" affiche "Demander le document"
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Et le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
      | Projectathon test evidence |

  Scénario: un document suivant refusé par le fournisseur se redemande seul, et la zone dit la combinaison récupérée une fois chaque document remis
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Et que le justificatif de "Projectathon test evidence" est remis
    Et que l'usager clique sur "Demander le document" dans le bloc de "Simple test evidence"
    Et que le fournisseur refuse la demande de "Simple test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "Document récupéré avec succès"
    Et le bloc de "Simple test evidence" affiche "Le document ne peut pas être fourni"
    Et le bloc de "Simple test evidence" affiche "EDM:ERR:0003"
    Et le bloc de "Simple test evidence" affiche "Redemander le document"
    Et la page n'affiche pas "Les documents demandés ont tous été récupérés"
    Et la liste des combinaisons de la carte est désactivée
    Quand l'usager recharge la page des justificatifs
    Alors le bloc de "Projectathon test evidence" affiche "Document récupéré avec succès"
    Et le bloc de "Simple test evidence" affiche "Redemander le document"
    Et la carte n'offre pas de liste des combinaisons
    Quand l'usager clique sur "Redemander le document" dans le bloc de "Simple test evidence"
    Alors le contrat a reçu, dans l'ordre et sous la même conversation, les demandes :
      | type                       |
      | Projectathon test evidence |
      | Simple test evidence       |
      | Simple test evidence       |
    Et le bloc de "Simple test evidence" affiche "Demande du document en cours"
    Quand le justificatif de "Simple test evidence" est remis
    Alors la zone affiche "Les documents demandés ont tous été récupérés" au-dessus de ses blocs
    Et le bloc de "Projectathon test evidence" ouvre le justificatif de son type
    Et le bloc de "Simple test evidence" ouvre le justificatif de son type
    Et la page n'affiche aucun bouton de demande

  Scénario: la combinaison tient au rechargement, une demande la retient, et un autre pays la défait
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Alors le bloc de "Projectathon test evidence" affiche "Demander le document"
    Quand l'usager recharge la page des justificatifs
    Alors la liste des combinaisons de la carte affiche "Compound test evidence"
    Et la carte nomme, ligne par ligne :
      | type                       | fournisseur                    |
      | Projectathon test evidence | Ministry of Digital Governance |
      | Simple test evidence       | Ministry of Digital Governance |
    Quand l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Alors le bloc de "Projectathon test evidence" affiche "Demande du document en cours"
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
    Quand l'usager choisit "Finlande (FI)" dans la liste des pays de la carte
    Alors la carte n'offre pas de liste des combinaisons
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Alors la liste des combinaisons de la carte affiche "Sélectionnez un document"

  Scénario: un premier document annoncé pour plus tard arrête la séquence, et la carte offre de nouveau ses listes
    Étant donné la Grèce publiant "Compound test evidence" pour l'exigence de la carte
    Et la Grèce désignant sans question le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Grèce (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Compound test evidence" dans la liste des combinaisons de la carte
    Et que l'usager clique sur "Demander le document" dans le bloc de "Projectathon test evidence"
    Et que le fournisseur répond à la demande de "Projectathon test evidence" par une réponse différée
    Alors le bloc de "Projectathon test evidence" affiche "Document annoncé pour plus tard"
    Et le bloc de "Simple test evidence" affiche "Sera demandé une fois le document précédent récupéré"
    Quand l'usager recharge la page des justificatifs
    Alors la liste des combinaisons de la carte affiche "Compound test evidence"
    Et la page affiche le bouton "Redemander le document"
    Et le bloc de "Simple test evidence" n'offre aucun bouton
