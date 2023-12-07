NETTOYAGES :
- Supprimer les namespaces dans les tests de `requeteJustificatif.spec.js`
- Utiliser un « builder » pour construire le XML passé à `new Requete` dans le test
- Nettoyer le code pour résoudre le « feature envy » dans l'adaptateur Domibus

PROCHAINES ÉTAPES :
- changer route `requete/diplomeSecondDegre` en `requete/pieceJustificative`
- Récupérer le code démarche sur l'URL de `requete/pieceJustificative`
- L'injecter dans la requête EBMS à envoyer sur Domibus
- Faire une PR
- Envoyer le PDF du drapeau plutôt qu'une erreur
