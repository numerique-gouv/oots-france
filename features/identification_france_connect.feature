# language: fr
@bout_en_bout
Fonctionnalité: Identifier un usager européen par un faux FranceConnect+

  Le bac à sable de FranceConnect+ ne répond qu'à un déploiement joignable, ce
  que l'intégration continue n'a pas. La suite lance donc son propre
  FranceConnect+, qui joue aussi la passerelle eIDAS et le nœud de l'État
  membre de l'usager, tels qu'un portail de démarche les voit. Ces scénarios
  éprouvent ce faux, endpoint par endpoint et refus par refus.

  Le faux FranceConnect+ reproduit ce que les sources publiées de FranceConnect
  font ; docs/test_e2e.md dit ce qu'il reproduit et ce dont il s'écarte
  sciemment.
  Le portail qui l'appelle ici est un client de test, qui n'a que la clé de
  déchiffrement de la démarche de démonstration.

  Contexte:
    Étant donné un faux FranceConnect+ lancé à côté du scénario
    Et un portail de test qui ne connaît de FranceConnect+ que son adresse de découverte

  Scénario: le document de découverte annonce les endpoints, et le JWKS se met en cache
    Quand le portail lit le document de découverte
    Alors le document contient l'issuer du faux FranceConnect+ et ses cinq autres endpoints
    Et le JWKS répond en "application/jwk-set+json" avec "public, max-age=600"

  Scénario: un appel /authorize complet ouvre la cinématique européenne sans passer par la mire
    Quand le portail appelle /authorize
    Alors la page de choix du pays s'affiche
    Quand le portail appelle /authorize avec ces paramètres:
      | prompt | consent |
    Alors la page de choix du pays s'affiche

  Scénario: /authorize répond aussi bien en POST
    Quand le portail appelle /authorize en POST
    Alors la page de choix du pays s'affiche

  Plan du Scénario: un appel /authorize malformé est refusé sans redirection
    Quand le portail appelle /authorize avec ces paramètres:
      | <paramètre> | <valeur> |
    Alors le faux FranceConnect+ répond une page d'erreur 400
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

  Scénario: deux refus renvoient le navigateur au portail, sur sa redirect_uri
    Quand le portail appelle /authorize avec ces paramètres:
      | acr_values | eidas1 |
    Alors le navigateur est redirigé vers la redirect_uri avec l'erreur "invalid_acr"
    Et l'error_description est "acr_value is not valid, should be equal one of these values, expected eidas2,eidas3, got eidas1"
    Et la redirection contient le state de l'appel et l'iss du faux FranceConnect+, et aucun code
    Quand le portail appelle /authorize avec ces paramètres:
      | idp_hint | impots |
    Alors le navigateur est redirigé vers la redirect_uri avec l'erreur "invalid_idp_hint"
    Et l'error_description est "An idp_hint was provided but is not allowed"
    Et la redirection contient le state de l'appel et l'iss du faux FranceConnect+, et aucun code

  Scénario: les trois pages mènent au code d'autorisation
    Quand le portail appelle /authorize
    Et que l'usager choisit le pays "DK"
    Alors la page des identités de test de ce pays s'affiche
    Quand l'usager choisit l'identité de test "dk-substantial"
    Alors la page de consentement liste les données transmises, en anglais
    Quand l'usager consent à la transmission de ses données
    Alors le navigateur est redirigé vers la redirect_uri avec un code et le state de l'appel

  Scénario: un pays ou une identité que le faux FranceConnect+ ne sert pas est refusé
    Quand le portail appelle /authorize
    Et que l'usager choisit un pays que le faux FranceConnect+ ne sert pas
    Alors le faux FranceConnect+ répond une page d'erreur 400
    Quand le portail appelle /authorize
    Et que l'usager choisit le pays "DK"
    Et qu'il choisit une identité que le faux FranceConnect+ ne connaît pas
    Alors le faux FranceConnect+ répond une page d'erreur 400

  Scénario: rejouer une étape après le consentement est refusé
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et qu'il rejoue la dernière étape
    Alors le faux FranceConnect+ répond une page d'erreur 400

  Scénario: une identité d'un niveau de garantie plus faible que celui demandé est refusée
    Quand le portail appelle /authorize avec ces paramètres:
      | acr_values | eidas3 |
    Et que l'usager choisit le pays "DK"
    Et que l'usager choisit l'identité de test "dk-substantial"
    Alors le faux FranceConnect+ répond une page d'erreur 400
    Et le navigateur n'est pas redirigé

  Scénario: une identité d'un niveau de garantie plus fort que celui demandé rend son propre niveau
    Quand l'usager s'identifie avec l'identité de test "dk-high" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Alors l'ID Token contient "acr" égal à "eidas3"

  Scénario: le code ne s'échange qu'une fois, dans les trente secondes, avec le secret dans le corps
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Alors la réponse contient un access_token, le type "Bearer", une durée de 60 secondes et un id_token
    Quand le portail rejoue le même code
    Alors /token refuse la demande
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le faux FranceConnect+ vieillit le code d'autorisation de 31 secondes
    Et que le portail échange le code contre les jetons
    Alors /token refuse la demande
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail présente son secret en "Authorization: Basic" seulement
    Alors /token refuse la demande

  Scénario: /token exige le secret du portail et le bon grant_type
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code avec un mauvais secret
    Alors /token refuse la demande
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code en annonçant un autre grant_type
    Alors /token refuse la demande

  Scénario: un code présenté avec une autre redirect_uri est refusé
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code en annonçant une autre redirect_uri
    Alors /token refuse la demande

  Scénario: un code émis pour un portail ne s'échange pas sous un autre
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et qu'un second portail échange ce code
    Alors /token refuse la demande

  Scénario: l'ID Token est signé par le faux FranceConnect+ et chiffré pour le seul portail
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Alors seule la clé privée du portail déchiffre l'id_token
    Et le JWT déchiffré est signé par une clé du JWKS du faux FranceConnect+
    Et le JWT déchiffré contient iss, sub, aud, exp, iat, nonce et acr
    Et le JWT déchiffré ne contient pas "amr"

  Scénario: l'ID Token contient amr quand l'appel l'a demandé
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2", en réclamant amr
    Et que le portail échange le code contre les jetons
    Alors l'ID Token contient "amr" égal à "eidas" seul

  Scénario: /userinfo ne rend que ce que les scopes couvrent
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Et qu'il appelle /userinfo
    Alors la réponse est en "application/jwt"
    Et le JWT déchiffré contient exactement sub, given_name, family_name, birthdate, gender et birthplace

  Scénario: /userinfo refuse un jeton d'accès qu'il n'a pas émis
    Quand le portail appelle /userinfo avec un jeton d'accès inconnu
    Alors /userinfo refuse la demande

  Scénario: un jeton d'accès expire au bout de soixante secondes
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Et que le faux FranceConnect+ vieillit le jeton d'accès de 61 secondes
    Et que le portail appelle /userinfo
    Alors /userinfo refuse la demande

  Scénario: le scope profile ajoute preferred_username, et rien d'autre
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2", avec le scope profile
    Et que le portail échange le code contre les jetons
    Et qu'il appelle /userinfo
    Alors le JWT déchiffré contient en plus "preferred_username", égal au "family_name"

  Scénario: le sub est un pseudonyme stable, différent pour chaque portail
    Quand l'usager s'identifie deux fois avec l'identité de test "dk-substantial"
    Alors les deux sub sont égaux, de 64 caractères hexadécimaux suivis de "v1"
    Et les deux sub ne ressemblent à aucun identifiant eIDAS
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" auprès d'un second portail
    Alors le sub obtenu par le second portail diffère de celui du premier

  Scénario: après une rotation des clés de signature, le JWKS relu vérifie le nouveau jeton
    Quand le portail lit le JWKS
    Et que le faux FranceConnect+ change de clé de signature
    Et que l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Alors le kid du jeton est absent du JWKS lu avant la rotation
    Et le kid du jeton est présent dans le JWKS relu après la rotation, et la signature s'y vérifie

  Scénario: /session/end ne redirige que vers une adresse déclarée
    Quand l'usager s'identifie avec l'identité de test "dk-substantial" au niveau demandé "eidas2"
    Et que le portail échange le code contre les jetons
    Et que le portail déconnecte l'usager vers l'adresse déclarée
    Alors le navigateur est redirigé vers cette adresse avec son state
    Quand le portail déconnecte l'usager vers une adresse non déclarée
    Alors le faux FranceConnect+ affiche sa page de déconnexion, sans rediriger
    Quand le portail déconnecte l'usager avec un paramètre inconnu
    Alors le faux FranceConnect+ répond une page d'erreur 400
    Quand le portail déconnecte l'usager avec un id_token_hint illisible
    Alors le faux FranceConnect+ répond une page d'erreur 400
    Quand le portail déconnecte l'usager sans id_token_hint
    Alors le faux FranceConnect+ répond une page d'erreur 400
