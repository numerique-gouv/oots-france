# language: fr
@javascript
Fonctionnalité: Demander un justificatif depuis la démarche de démonstration dans un navigateur

  La zone de demande de la page des justificatifs est l'endroit de la console
  où le navigateur décide le plus par lui-même : l'attente prend la place du
  bouton avant qu'aucune réponse ne soit revenue, l'adresse de la zone est
  interrogée tant que la demande court, une seule interrogation à la fois, et
  une suite d'échecs fait renoncer la zone en offrant le retour à la page. Le
  serveur décide de tout le reste, et ce qu'il dit déjà à l'écran n'est jamais
  reconstruit.

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

  Scénario: une session finie pendant l'attente mène à la page de connexion dans la fenêtre
    Étant donné une demande en cours
    Et une interrogation retenue devant le navigateur
    Quand le compte de l'administrateur est supprimé
    Et que l'interrogation retenue est libérée
    Alors la page de connexion s'affiche
    Et la page n'affiche pas "This page could not reach the service."
