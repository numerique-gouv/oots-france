# language: fr
@javascript
Fonctionnalité: Demander un justificatif depuis la démarche de démonstration dans un navigateur

  La zone de demande de la page des justificatifs est l'endroit de la console
  où le navigateur décide le plus par lui-même : l'attente prend la place du
  bouton avant qu'aucune réponse ne soit revenue, l'adresse de la zone est
  interrogée tant que la demande court, une seule interrogation à la fois, et
  une suite d'échecs fait renoncer la zone en offrant le retour à la page. Deux
  cartes cliquées coup sur coup y suivent chacune sa propre demande, quel que
  soit l'ordre dans lequel les réponses reviennent. Le choix du pays
  fournisseur s'y joue aussi : la carte nomme ce que le pays choisi publie, sur
  chaque carte de la page, et la demande part vers lui ; un choix resté sans
  réponse laisse la carte dans son pays et le dit à côté de la liste. Une
  carte ajoutée depuis le catalogue de l'Evidence Broker s'y tient sous celles
  de la démarche, change de pays, se demande et se retire comme elles. Le
  serveur décide de tout le reste, et ce qu'il dit déjà à l'écran n'est jamais
  reconstruit. Le choix du type de justificatif s'y joue de même, quand le pays
  en publie plusieurs pour l'exigence : rien n'est choisi à la place de
  l'usager, la carte se résout sur le type qu'il choisit, et la demande part
  avec lui. La question que le Data Service Directory pose avant de pouvoir
  désigner le fournisseur s'y pose aussi, sur la carte, dans la forme que son
  type demande : la réponse de l'usager résout la carte, et la demande part
  avec elle.

  Ces scénarios demandent un navigateur sans tête, et rien de plus : ni
  passerelle, ni annuaire réel, ni FranceConnect+ réel. docs/test_e2e.md les
  situe parmi les configurations de la suite.

  Contexte:
    Étant donné les annuaires et le contrat de la démarche doublés
    Et un compte d'administrateur
    Et un administrateur connecté à l'espace d'administration
    Et l'usager identifié sur la page des justificatifs

  Scénario: l'attente prend la place du bouton avant qu'aucune réponse ne soit revenue
    Étant donné la soumission de la demande retenue devant le navigateur
    Quand l'usager clique sur "Request the document"
    Alors la zone annonce qu'elle attend
    Et la page n'affiche aucun bouton de demande
    Et la page des justificatifs est toujours affichée
    Et le contrat n'a reçu aucune demande
    Quand la soumission retenue est libérée
    Alors le contrat a reçu la demande
    Et la zone annonce toujours la même attente

  Scénario: une interrogation qui dit la même attente ne remplace rien, et une seule court à la fois
    Étant donné une demande en cours
    Et la première interrogation laissée passer, la deuxième retenue devant le navigateur
    Alors la zone annonce qu'elle attend
    Quand la zone interroge son adresse
    Alors la zone annonce toujours la même attente
    Et aucune autre interrogation ne part
    Quand le justificatif est remis
    Et que l'interrogation retenue est libérée
    Alors la page affiche "Document retrieved successfully"
    Et la page affiche "Open the document"
    Et la page des justificatifs n'a pas été rechargée
    Et la zone n'a pas été remplacée, seulement son contenu
    Et aucune autre interrogation ne part

  Scénario: une page rechargée sur une demande en cours reprend l'attente d'elle-même
    Étant donné une demande en cours
    Quand l'usager recharge la page des justificatifs
    Alors la zone annonce qu'elle attend
    Et la page n'affiche aucun bouton de demande
    Quand le justificatif est remis
    Alors la page affiche "Document retrieved successfully"
    Et la page des justificatifs n'a pas été rechargée
    Et la zone n'a pas été remplacée, seulement son contenu

  Scénario: deux interrogations sans réponse exploitable ne changent rien à l'écran
    Étant donné une demande en cours
    Et la première interrogation coupée, la deuxième répondue sans l'en-tête "Deferred-Fragment" devant le navigateur
    Quand deux interrogations de suite n'obtiennent aucune réponse exploitable
    Alors la zone annonce toujours la même attente
    Et la page n'affiche pas "This page could not reach the service."
    Quand le justificatif est remis
    Alors la page affiche "Document retrieved successfully"

  Scénario: trois interrogations sans réponse font renoncer la zone, qui offre le retour à la page
    Étant donné une demande en cours
    Et les trois interrogations suivantes coupées devant le navigateur
    Quand la zone renonce à joindre le service
    Alors la page affiche "This page could not reach the service."
    Et la page affiche le lien "Reload the page"
    Et la page n'affiche pas "Requesting the document…"
    Et la page n'affiche aucun bouton de demande
    Quand l'usager suit le lien "Reload the page"
    Alors la zone annonce qu'elle attend

  Scénario: une demande dont la réponse se perd est retentée par l'interrogation, jamais renvoyée
    Étant donné la soumission de la demande et les deux requêtes suivantes coupées devant le navigateur
    Quand l'usager clique sur "Request the document"
    Alors la zone annonce qu'elle attend
    Et les essais qui suivent la soumission sont des interrogations
    Et le contrat n'a reçu aucune demande
    Quand la zone renonce à joindre le service
    Alors la page affiche "This page could not reach the service."
    Et la page affiche le lien "Reload the page"
    Et la page n'affiche pas "Requesting the document…"
    Et la page n'affiche aucun bouton de demande
    Quand l'usager suit le lien "Reload the page"
    Alors la page affiche le bouton "Request the document"

  Scénario: la demande retenue n'est pas perdue par la réponse qui revient avant la sienne
    Étant donné les deux exigences de la démarche affichées
    Et la soumission de la demande retenue devant le navigateur
    Quand l'usager clique sur le bouton de la première carte
    Et que l'usager clique sur le bouton de la seconde carte
    Alors la zone de la seconde carte annonce qu'elle attend
    Et le contrat a reçu la demande de la seconde carte
    Quand la soumission retenue est libérée
    Alors les deux zones annoncent qu'elles attendent
    Quand l'usager recharge la page des justificatifs
    Alors les deux zones annoncent qu'elles attendent

  Scénario: deux soumissions retenues ensemble laissent chaque zone sur sa propre demande
    Étant donné les deux exigences de la démarche affichées
    Et les soumissions des deux cartes retenues devant le navigateur
    Quand l'usager clique sur le bouton de la première carte
    Et que l'usager clique sur le bouton de la seconde carte
    Et que les deux soumissions retenues sont libérées dans l'ordre des clics
    Alors les deux zones annoncent qu'elles attendent
    Quand l'usager recharge la page des justificatifs
    Alors les deux zones annoncent qu'elles attendent

  Scénario: une session finie pendant l'attente mène à la page de connexion dans la fenêtre
    Étant donné une demande en cours
    Et une interrogation retenue devant le navigateur
    Quand le compte de l'administrateur est supprimé
    Et que l'interrogation retenue est libérée
    Alors la page de connexion s'affiche
    Et la page n'affiche pas "This page could not reach the service."

  Scénario: la carte nomme ce que publie le pays choisi, et la demande part vers lui
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la carte nomme le pays "Finland (FI)"
    Et la carte annonce "Keha v. 2.0"
    Et la page affiche "Keha v. 2.0"
    Et la page des justificatifs n'a pas été rechargée
    Et le contrat n'a reçu aucune demande
    Quand l'usager clique sur "Request the document"
    Alors le contrat a reçu la demande pour le pays "FI"

  Scénario: le pays choisi sur une deuxième carte nommée la résout sans recharger la page, et la demande part vers lui
    Étant donné les deux exigences de la démarche affichées
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la seconde carte
    Alors la seconde carte nomme le pays "Finland (FI)"
    Et la première carte nomme le pays "France (FR)"
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager clique sur le bouton de la seconde carte
    Alors le contrat a reçu la demande pour le pays "FI"

  Scénario: un choix de pays resté sans réponse laisse la carte dans son pays et le dit, jusqu'au choix suivant qui aboutit
    Étant donné le choix du pays répondu en "502" sans l'en-tête "Deferred-Fragment", puis coupé, devant le navigateur
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la carte affiche "The country could not be changed: this page could not reach the service."
    Et la carte annonce "The country could not be changed: this page could not reach the service."
    Et la liste des pays de la carte affiche "France (FR)"
    Et la carte nomme le pays "France (FR)"
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la carte affiche "The country could not be changed: this page could not reach the service."
    Et la liste des pays de la carte affiche "France (FR)"
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la carte nomme le pays "Finland (FI)"
    Et la page n'affiche pas "The country could not be changed"
    Et la page des justificatifs n'a pas été rechargée
    Quand le choix suivant du pays est coupé devant le navigateur
    Et que l'usager choisit "Germany (DE)" dans la liste des pays de la carte
    Alors la carte affiche "The country could not be changed: this page could not reach the service."
    Et la liste des pays de la carte affiche "Finland (FI)"
    Et la carte nomme le pays "Finland (FI)"

  Scénario: un choix de pays refusé par la page la recharge, et une session finie mène à la page de connexion
    Étant donné le choix du pays répondu en "422" sans l'en-tête "Deferred-Fragment" devant le navigateur
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la page des justificatifs a été rechargée
    Et la page n'affiche pas "The country could not be changed"
    Quand le compte de l'administrateur est supprimé
    Et que l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la page de connexion s'affiche

  Scénario: une carte ajoutée se tient sous celles de la démarche, se demande dans son pays, et revient dans ce pays une fois retirée
    Étant donné le catalogue de l'Evidence Broker offert sous les cartes de la démarche
    Quand l'usager ajoute la carte "(TEST) Test Requirement 2"
    Alors la carte "(TEST) Test Requirement 2" se tient sous celles de la démarche, avec le bouton "Remove this document"
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte "(TEST) Test Requirement 2"
    Alors la carte "(TEST) Test Requirement 2" nomme le pays "Finland (FI)"
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager clique sur le bouton de la carte "(TEST) Test Requirement 2"
    Alors le contrat a reçu la demande pour le pays "FI"
    Quand l'usager retire la carte "(TEST) Test Requirement 2"
    Alors la page n'affiche pas la carte "(TEST) Test Requirement 2"
    Quand l'usager ajoute la carte "(TEST) Test Requirement 2"
    Alors la carte "(TEST) Test Requirement 2" nomme le pays "Finland (FI)"

  Scénario: la carte offre les types que le pays publie, se résout sur celui que l'usager choisit, et la demande part avec lui
    Étant donné l'Autriche publiant deux types de justificatif pour l'exigence de la carte
    Et l'usager identifié sur la page des justificatifs d'un parcours en 1.2
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Alors la liste des types de la carte affiche "Select a document"
    Et la liste des types de la carte offre "Test Evidence Austria (AT)" puis "Austrian Test Evidence Type without Reauthentication"
    Et la carte ne nomme aucun fournisseur
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Evidence impossible to satisfy"
    Quand l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la carte nomme le type "Test Evidence Austria (AT)" et le fournisseur "Test Evidence Provider Austria (AT)"
    Et la page affiche le bouton "Request the document"
    Et la liste des types de la carte affiche "Test Evidence Austria (AT)"
    Et la liste des types de la carte n'offre plus "Select a document"
    Et la carte annonce "Test Evidence Provider Austria (AT)"
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager choisit "Austrian Test Evidence Type without Reauthentication" dans la liste des types de la carte
    Alors la carte nomme le type "Austrian Test Evidence Type without Reauthentication" et le fournisseur "Test Evidence Provider Austria (AT)"
    Et la liste des types de la carte affiche "Austrian Test Evidence Type without Reauthentication"
    Et la page des justificatifs n'a pas été rechargée
    Et le contrat n'a reçu aucune demande
    Quand l'usager clique sur "Request the document"
    Alors le contrat a reçu la demande pour le type "Austrian Test Evidence Type without Reauthentication"
    Quand l'usager recharge la page des justificatifs
    Alors la carte n'offre pas de liste des pays
    Et la carte n'offre pas de liste des types
    Et la carte nomme le pays "Austria (AT)"
    Et la carte nomme le type "Austrian Test Evidence Type without Reauthentication" et le fournisseur "Test Evidence Provider Austria (AT)"

  Scénario: un type que personne ne fournit, ou dont le fournisseur ne parle pas la version du parcours, se choisit sans rendre l'exigence insatisfaisable
    Étant donné l'Autriche publiant deux types de justificatif pour l'exigence de la carte
    Et aucun fournisseur publié en Autriche pour "Austrian Test Evidence Type without Reauthentication"
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Et que l'usager choisit "Austrian Test Evidence Type without Reauthentication" dans la liste des types de la carte
    Alors la page affiche "No provider listed by Austria for this evidence"
    Et la page n'affiche aucun bouton de demande
    Et la liste des types de la carte affiche "Austrian Test Evidence Type without Reauthentication"
    Et la page n'affiche pas "Evidence impossible to satisfy"
    Quand l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la page affiche "This provider does not support OOTS 2.0"
    Et la page n'affiche aucun bouton de demande
    Et la liste des types de la carte affiche "Test Evidence Austria (AT)"

  Scénario: un choix de type resté sans réponse laisse la carte sur son type et le dit, jusqu'au choix suivant qui aboutit
    Étant donné l'Autriche publiant deux types de justificatif pour l'exigence de la carte
    Et le choix du type répondu en "502" sans l'en-tête "Deferred-Fragment", puis coupé, devant le navigateur
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Et que l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la carte affiche "The document could not be changed: this page could not reach the service."
    Et la carte annonce "The document could not be changed: this page could not reach the service."
    Et la liste des types de la carte affiche "Select a document"
    Et la carte ne nomme aucun fournisseur
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la carte affiche "The document could not be changed: this page could not reach the service."
    Et la liste des types de la carte affiche "Select a document"
    Quand l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la carte nomme le type "Test Evidence Austria (AT)" et le fournisseur "Test Evidence Provider Austria (AT)"
    Et la page n'affiche pas "The document could not be changed"
    Et la page des justificatifs n'a pas été rechargée
    Quand le choix suivant du type est coupé devant le navigateur
    Et que l'usager choisit "Austrian Test Evidence Type without Reauthentication" dans la liste des types de la carte
    Alors la carte affiche "The document could not be changed: this page could not reach the service."
    Et la liste des types de la carte affiche "Test Evidence Austria (AT)"
    Et la carte nomme le type "Test Evidence Austria (AT)" et le fournisseur "Test Evidence Provider Austria (AT)"

  Scénario: un choix de type refusé par la page la recharge, et une session finie mène à la page de connexion
    Étant donné l'Autriche publiant deux types de justificatif pour l'exigence de la carte
    Et le choix du type répondu en "422" sans l'en-tête "Deferred-Fragment" devant le navigateur
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Et que l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la page des justificatifs a été rechargée
    Et la page n'affiche pas "The document could not be changed"
    Quand le compte de l'administrateur est supprimé
    Et que l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Alors la page de connexion s'affiche

  Scénario: le type choisi tient au rechargement, et un autre pays ou une nouvelle identification le défont
    Étant donné l'Autriche publiant deux types de justificatif pour l'exigence de la carte
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Et que l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Et que l'usager recharge la page des justificatifs
    Alors la liste des types de la carte affiche "Test Evidence Austria (AT)"
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Alors la liste des pays de la carte affiche "Finland (FI)"
    Et la carte n'offre pas de liste des types
    Et la page affiche "Keha v. 2.0"
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Alors la liste des types de la carte affiche "Select a document"
    Et la page n'affiche aucun bouton de demande
    Quand l'usager choisit "Test Evidence Austria (AT)" dans la liste des types de la carte
    Et que l'usager s'identifie de nouveau, dans un parcours en 1.2
    Alors la liste des pays de la carte affiche "France (FR)"
    Et la carte n'offre pas de liste des types
    Quand l'usager choisit "Austria (AT)" dans la liste des pays de la carte
    Alors la liste des types de la carte affiche "Select a document"
    Et la page n'affiche aucun bouton de demande

  Scénario: la carte pose la question du Data Service Directory, se résout sur la réponse de l'usager, et la demande part avec elle
    Étant donné la Grèce posant une question sur le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Alors la carte pose la question "Projectathon test case" dans une liste ouverte sur "Select a value"
    Et la question "Projectathon test case" offre "TC03 - Evidence request error flow due to Basic Registry error"
    Et la carte ne nomme aucun fournisseur
    Et la page n'affiche aucun bouton de demande
    Et la page n'affiche pas "Evidence impossible to satisfy"
    Et la carte n'offre pas de bouton pour répondre
    Et le Data Service Directory n'a reçu aucune réponse
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
    Et la page affiche le bouton "Request the document"
    Et la question "Projectathon test case" affiche "TC03 - Evidence request error flow due to Basic Registry error"
    Et la question "Projectathon test case" n'offre plus "Select a value"
    Et la carte annonce "Ministry of Digital Governance"
    Et la page des justificatifs n'a pas été rechargée
    Et le Data Service Directory a reçu la réponse "TC03" à la question "Projectathon test case"
    Quand l'usager clique sur "Request the document"
    Alors le contrat a reçu la demande avec la réponse "TC03" à la question "Projectathon test case"

  Scénario: une liste de valeurs illisible fait poser la question en texte, et un refus de la réponse se dit comme tout refus
    Étant donné la Grèce posant une question sur le fournisseur de "Projectathon test evidence"
    Et la liste des valeurs de la question injoignable
    Et le Data Service Directory refusant la réponse "TC02" en "DSD:ERR:0001"
    Et le Data Service Directory refusant la réponse "TC04" en "DSD:ERR:0006"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Alors la carte pose la question "Projectathon test case" dans un champ texte
    Quand l'usager répond "TC02" à la question "Projectathon test case"
    Alors la page affiche "No provider listed by Greece for this evidence"
    Et la page n'affiche aucun bouton de demande
    Et la question "Projectathon test case" affiche "TC02"
    Et la page n'affiche pas "Evidence impossible to satisfy"
    Quand l'usager répond "TC04" à la question "Projectathon test case"
    Alors la page affiche "Greece could not answer for this evidence"
    Et la page n'affiche aucun bouton de demande
    Quand l'usager répond "TC03" à la question "Projectathon test case"
    Alors la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"

  Scénario: la carte pose chaque question dans la forme que son type demande, et une exception sans question se dit comme un refus
    Étant donné la Grèce posant une question de chaque type sur le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Alors la carte pose, dans l'ordre, les questions :
      | question               | forme            |
      | Projectathon test case | liste            |
      | Were you born abroad?  | "Yes" ou "No"    |
      | Your passport number   | champ texte      |
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Et que l'usager répond "Yes" à la question "Were you born abroad?"
    Alors le Data Service Directory n'a reçu aucune réponse
    Quand l'usager répond "AB123456" à la question "Your passport number"
    Alors la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
    Et le Data Service Directory a reçu la réponse "true" à la question "Were you born abroad?"
    Et le Data Service Directory a reçu la réponse "AB123456" à la question "Your passport number"
    Quand la Grèce ne pose plus que sa question sans classification
    Et que l'usager recharge la page des justificatifs
    Alors la page affiche "Greece could not answer for this evidence"
    Et la carte n'offre aucune question

  Scénario: une réponse restée sans réponse laisse la carte comme elle était et le dit, jusqu'à la réponse suivante qui aboutit
    Étant donné la Grèce posant une question sur le fournisseur de "Projectathon test evidence"
    Et la réponse aux questions répondue en "502" sans l'en-tête "Deferred-Fragment", puis coupée, devant le navigateur
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Et que l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la carte affiche sous ses questions "The answer could not be sent: this page could not reach the service."
    Et la carte annonce "The answer could not be sent: this page could not reach the service."
    Et la question "Projectathon test case" affiche "TC03 - Evidence request error flow due to Basic Registry error"
    Et la carte ne nomme aucun fournisseur
    Et la page des justificatifs n'a pas été rechargée
    Quand l'usager répond "TC06 - Basic evidence request with reauthentication and preview" à la question "Projectathon test case"
    Alors la carte affiche sous ses questions "The answer could not be sent: this page could not reach the service."
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
    Et la page n'affiche pas "The answer could not be sent"
    Et la page des justificatifs n'a pas été rechargée

  Scénario: la réponse tient au rechargement, une demande la retient, et un autre pays la défait
    Étant donné la Grèce posant une question sur le fournisseur de "Projectathon test evidence"
    Quand l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Et que l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Alors la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
    Quand l'usager recharge la page des justificatifs
    Alors la question "Projectathon test case" affiche "TC03 - Evidence request error flow due to Basic Registry error"
    Et la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
    Et le Data Service Directory a reçu sa requête sans la réponse, puis avec elle
    Quand l'usager choisit "Finland (FI)" dans la liste des pays de la carte
    Et que l'usager choisit "Greece (EL)" dans la liste des pays de la carte
    Et que l'usager choisit "Projectathon test evidence" dans la liste des types de la carte
    Alors la carte pose la question "Projectathon test case" dans une liste ouverte sur "Select a value"
    Quand l'usager répond "TC03 - Evidence request error flow due to Basic Registry error" à la question "Projectathon test case"
    Et que l'usager clique sur "Request the document"
    Et que l'usager recharge la page des justificatifs
    Alors la carte n'offre aucune question
    Et la carte nomme le type "Projectathon test evidence" et le fournisseur "Ministry of Digital Governance"
