# language: fr
@bout_en_bout
Fonctionnalité: Identifier un usager européen par un faux FranceConnect+

  La démarche de démonstration n'a pas d'autre moyen de tenir l'identité d'un
  usager européen : le bac à sable FranceConnect+ attend un déploiement
  joignable, que l'intégration continue ne lui donne pas. Le dépôt joue donc
  FranceConnect+ lui-même, et derrière lui la passerelle eIDAS et le nœud d'un
  État membre, tels qu'un fournisseur de service les voit.

  Ce que le faux rend, refuse, vérifie et enchaîne vient des sources de
  FranceConnect lues au commit 93cd5d7 ; rien n'en est copié ni construit.
  docs/test_e2e.md dit ce qu'il reproduit et ce dont il s'écarte sciemment.

  Aucune ligne de la démarche n'existe encore : c'est un client du test qui
  suit les trois pages et ouvre les jetons avec la clé de la démarche. La
  traversée par la démarche elle-même est OOTS-179 puis OOTS-181.

  Contexte:
    Étant donné un faux FranceConnect+ qui tourne à côté du scénario
    Et un client du test qui ne connaît de lui que son adresse de découverte

  Scénario: la découverte annonce les endpoints, et le JWKS se met en cache
    Quand le client lit le document de découverte
    Alors il y trouve l'issuer du faux et ses cinq autres endpoints
    Et le JWKS répond en "application/jwk-set+json" avec "public, max-age=600"

  Scénario: un appel complet ouvre la cinématique européenne sans mire
    Quand le client appelle /authorize
    Alors la page de choix du pays s'ouvre
    Quand le client appelle /authorize avec ces paramètres:
      | prompt | consent |
    Alors la page de choix du pays s'ouvre

  Scénario: /authorize répond aussi bien en POST
    Quand le client appelle /authorize en POST
    Alors la page de choix du pays s'ouvre

  Plan du Scénario: un appel malformé est refusé sans redirection
    Quand le client appelle /authorize avec ces paramètres:
      | <paramètre> | <valeur> |
    Alors le faux répond une page d'erreur 400
    Et le navigateur n'est pas redirigé

    Exemples:
      | paramètre     | valeur                          |
      | nonce         | 12345678901234567890            |
      | state         |                                 |
      | prompt        | none                            |
      | response_type | token                           |
      | fantaisie     | oui                             |
      | redirect_uri  | https://ailleurs.invalid/retour |
      | idp_hint      |                                 |
      | client_id     | une-demarche-inconnue           |
      | scope         | openid inexistant               |
      | claims        | ceci n'est pas du JSON          |
      | scope         | given_name                      |
      | redirect_uri  | /retour                         |

  Scénario: deux refus reviennent à la démarche sur sa redirect_uri
    Quand le client appelle /authorize avec ces paramètres:
      | acr_values | eidas1 |
    Alors le navigateur revient sur la redirect_uri avec l'erreur "invalid_acr"
    Et l'error_description est "acr_value is not valid, should be equal one of these values, expected eidas2,eidas3, got eidas1"
    Et le retour porte le state de l'appel, l'iss du faux, et aucun code
    Quand le client appelle /authorize avec ces paramètres:
      | idp_hint | impots |
    Alors le navigateur revient sur la redirect_uri avec l'erreur "invalid_idp_hint"
    Et l'error_description est "An idp_hint was provided but is not allowed"
    Et le retour porte le state de l'appel, l'iss du faux, et aucun code

  Scénario: les trois pages mènent au code d'autorisation
    Quand le client appelle /authorize
    Et qu'il choisit le pays "DK"
    Alors la page des identités de test de ce pays s'ouvre
    Quand il choisit l'identité "dk-substantial"
    Alors la page de confirmation liste les données transmises, en anglais
    Quand il confirme la transmission
    Alors le navigateur revient sur la redirect_uri avec un code et le state de l'appel

  Scénario: le pays et l'identité choisis sont ceux que le faux sert, ou rien
    Quand le client appelle /authorize
    Et qu'il choisit un pays que le faux ne sert pas
    Alors le faux répond une page d'erreur 400
    Quand le client appelle /authorize
    Et qu'il choisit le pays "DK"
    Et qu'il choisit une identité que le faux ne connaît pas
    Alors le faux répond une page d'erreur 400

  Scénario: une étape rejouée après le consentement ne mène nulle part
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il rejoue la dernière étape
    Alors le faux répond une page d'erreur 400

  Scénario: une identité d'un niveau plus faible que celui demandé est refusée
    Quand le client appelle /authorize avec ces paramètres:
      | acr_values | eidas3 |
    Et qu'il choisit le pays "DK"
    Et qu'il choisit l'identité "dk-substantial"
    Alors le faux répond une page d'erreur 400
    Et le navigateur n'est pas redirigé

  Scénario: une identité d'un niveau plus fort que celui demandé rend son propre niveau
    Quand le client s'identifie comme "dk-high" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Alors l'ID Token porte "acr" à "eidas3"

  Scénario: le code s'échange une fois, dans les trente secondes, et par le corps
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Alors la réponse porte access_token, "Bearer", 60 secondes et un id_token
    Quand il rejoue le même code
    Alors /token le refuse
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et que le faux vieillit ses codes de 31 secondes
    Et qu'il échange le code contre les jetons
    Alors /token le refuse
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il présente le secret en "Authorization: Basic" seulement
    Alors /token le refuse

  Scénario: /token exige le secret du client et le bon grant_type
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code avec un mauvais secret
    Alors /token le refuse
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code en annonçant un autre grant_type
    Alors /token le refuse

  Scénario: un code présenté avec une autre redirect_uri est refusé
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code en annonçant une autre redirect_uri
    Alors /token le refuse

  Scénario: un code émis pour un client ne s'échange pas sous un autre
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'un second client du test échange ce code
    Alors /token le refuse

  Scénario: l'ID Token est signé pour le faux et chiffré pour la seule démarche
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Alors seule la clé privée de la démarche ouvre l'id_token
    Et le JWT intérieur est signé par une clé du JWKS du faux
    Et il porte iss, sub, aud, exp, iat, nonce et acr
    Et il ne porte pas "amr"

  Scénario: l'ID Token porte amr quand l'appel l'a demandé
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2", en réclamant amr
    Et qu'il échange le code contre les jetons
    Alors l'ID Token porte "amr" à "eidas" seul

  Scénario: /userinfo ne rend que ce que les scopes couvrent
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Et qu'il appelle /userinfo
    Alors la réponse est en "application/jwt"
    Et le JWT déchiffré porte exactement sub, given_name, family_name, birthdate, gender et birthplace

  Scénario: /userinfo refuse un jeton d'accès qu'il n'a pas émis
    Quand le client appelle /userinfo avec un jeton d'accès inconnu
    Alors /userinfo le refuse

  Scénario: un jeton d'accès expire au bout de soixante secondes
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Et que le faux vieillit ses jetons d'accès de 61 secondes
    Et qu'il appelle /userinfo
    Alors /userinfo le refuse

  Scénario: le scope profile ajoute preferred_username, et rien d'autre
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2", avec le scope profile
    Et qu'il échange le code contre les jetons
    Et qu'il appelle /userinfo
    Alors le JWT déchiffré porte en plus "preferred_username" égal au "family_name"

  Scénario: le sub est un pseudonyme stable, par client
    Quand le client s'identifie deux fois comme "dk-substantial"
    Alors les deux sub sont égaux, de 64 caractères hexadécimaux suivis de "v1"
    Et ils ne ressemblent à aucun identifiant eIDAS
    Quand un second client du test s'identifie comme "dk-substantial"
    Alors son sub diffère de celui du premier

  Scénario: les clés de signature tournent, et le lecteur relit le JWKS
    Quand le client lit le JWKS
    Et que le faux change de clé de signature
    Et que le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Alors le kid du jeton est absent du JWKS lu avant la rotation
    Et il est présent dans le JWKS relu après elle, et sa signature s'y vérifie

  Scénario: /session/end ne redirige que vers une adresse déclarée
    Quand le client s'identifie comme "dk-substantial" en demandant "eidas2"
    Et qu'il échange le code contre les jetons
    Et qu'il se déconnecte vers l'adresse déclarée
    Alors le navigateur est redirigé vers cette adresse avec son state
    Quand il se déconnecte vers une adresse non déclarée
    Alors le faux affiche la page de déconnexion, sans rediriger
    Quand il se déconnecte avec un paramètre inconnu
    Alors le faux répond une page d'erreur 400
    Quand il se déconnecte avec un id_token_hint illisible
    Alors le faux répond une page d'erreur 400
    Quand il se déconnecte sans id_token_hint
    Alors le faux répond une page d'erreur 400
