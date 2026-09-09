DECLARED_CLAIMS = %w[sub given_name family_name birthdate gender birthplace].freeze
ID_TOKEN_CLAIMS = %w[iss sub aud exp iat nonce acr].freeze

# The fake is a role of the suite: it is already running when the first step
# runs, and no step mounts it. What the scenario drives — a key rotation, a
# code aged past its lifetime — it drives over HTTP, from outside the process.
Étantdonné('un faux FranceConnect+ qui tourne à côté du scénario') do
  @issuer = ENV.fetch('URL_FAUX_FRANCE_CONNECT')
  @france_connect = FakeFranceConnect.running ||
                    FakeFranceConnect::Runner.new(issuer: @issuer, procedure_url: procedure_url)

  expect(FakeFranceConnect::Runner.answering?(@issuer)).to be(true)
end

Étantdonné('un client du test qui ne connaît de lui que son adresse de découverte') do
  @client = client_declared_as(FakeFranceConnect::Clients::PRIMARY_ID)
end

Quand('le client lit le document de découverte') do
  @discovery = @client.discovery_response
end

Alors('il y trouve l\'issuer du faux et ses cinq autres endpoints') do
  document = JSON.parse(@discovery.body)

  expect(document.fetch('issuer')).to eq(@issuer)

  # `all(...)` is Capybara's finder in this world, not the RSpec matcher.
  document.values_at('authorization_endpoint', 'token_endpoint', 'userinfo_endpoint', 'jwks_uri',
    'end_session_endpoint').each { |endpoint| expect(endpoint).to start_with(@issuer) }
end

Alors('le JWKS répond en {string} avec {string}') do |type, cache|
  key_set = @client.key_set_response

  expect(key_set.headers['Content-Type']).to include(type)
  expect(key_set.headers['Cache-Control']).to eq(cache)
end

Quand('le client appelle \\/authorize') do
  @reponse = @client.authorize
end

Quand('le client appelle \\/authorize en POST') do
  @reponse = @client.authorize(http_method: :post)
end

Quand('le client appelle \\/authorize avec ces paramètres:') do |parameters|
  @reponse = @client.authorize(**parameters.rows_hash.symbolize_keys.transform_values(&:presence))
end

Alors('la page de choix du pays s\'ouvre') do
  expect(@reponse.status).to eq(200)
  expect(@client.title).to eq('Choose your country')
end

Alors('le faux répond une page d\'erreur {int}') do |status|
  expect(@reponse.status).to eq(status)
end

Alors('le navigateur n\'est pas redirigé') do
  expect(@reponse.status).not_to eq(302)
end

Alors('le navigateur revient sur la redirect_uri avec l\'erreur {string}') do |error|
  expect(@reponse.status).to eq(302)
  expect(@reponse.headers['Location']).to start_with(@client.redirect_uri)
  expect(@client.returned['error']).to eq(error)
end

Alors('l\'error_description est {string}') do |description|
  expect(@client.returned['error_description']).to eq(description)
end

Alors('le retour porte le state de l\'appel, l\'iss du faux, et aucun code') do
  expect(@client.returned).to include('state' => @client.state, 'iss' => @issuer)
  expect(@client.returned).not_to have_key('code')
end

Quand('il choisit le pays {string}') do |code|
  @reponse = @client.choose_country(code)
end

Alors('la page des identités de test de ce pays s\'ouvre') do
  expect(@reponse.status).to eq(200)
  expect(@client.title).to eq('Choose a test identity')
end

Quand('il choisit l\'identité {string}') do |key|
  @reponse = @client.choose_identity(key)
end

Quand('il choisit un pays que le faux ne sert pas') do
  @reponse = @client.choose_country('ZZ')
end

Quand('il choisit une identité que le faux ne connaît pas') do
  @reponse = @client.choose_identity('personne')
end

Quand('il rejoue la dernière étape') do
  @reponse = @client.resubmit('consent', 'yes')
end

Alors('la page de confirmation liste les données transmises, en anglais') do
  expect(@client.title).to eq('Authorise the transmission of your data')
  expect(@reponse.body).to include('will be transmitted', 'Freja Marie', 'Sørensen')
end

Quand('il confirme la transmission') do
  @reponse = @client.confirm
end

Alors('le navigateur revient sur la redirect_uri avec un code et le state de l\'appel') do
  expect(@reponse.status).to eq(302)
  expect(@reponse.headers['Location']).to start_with(@client.redirect_uri)
  expect(@client.returned).to include('state' => @client.state)
  expect(@client.returned['code']).to be_present
end

Quand('le client s\'identifie comme {string} en demandant {string}') do |key, acr|
  @returned = identify(@client, key, acr_values: acr)
end

Quand('le client s\'identifie comme {string} en demandant {string}, en réclamant amr') do |key, acr|
  @returned = identify(@client, key, acr_values: acr, claims: '{"id_token":{"amr":{"essential":true}}}')
end

Quand('le client s\'identifie comme {string} en demandant {string}, avec le scope profile') do |key, acr|
  @returned = identify(@client, key, acr_values: acr, scope: "#{FranceConnectClient::DEFAULT_SCOPE} profile")
end

Quand('il échange le code contre les jetons') do
  @exchange = @client.exchange(@returned.fetch('code'))
  @tokens = JSON.parse(@exchange.body) if @exchange.status == 200
end

Alors('la réponse porte access_token, {string}, {int} secondes et un id_token') do |type, expiry|
  expect(@exchange.status).to eq(200)
  expect(@tokens).to include('token_type' => type, 'expires_in' => expiry)
  expect(@tokens['access_token']).to be_present
  expect(@tokens['id_token']).to be_present
end

Quand('il rejoue le même code') do
  @exchange = @client.exchange(@returned.fetch('code'))
end

Quand('il échange le code avec un mauvais secret') do
  @exchange = @client.exchange(@returned.fetch('code'), client_secret: 'ce-n-est-pas-le-secret')
end

Quand('il échange le code en annonçant un autre grant_type') do
  @exchange = @client.exchange(@returned.fetch('code'), grant_type: 'password')
end

Quand('il échange le code en annonçant une autre redirect_uri') do
  @exchange = @client.exchange(@returned.fetch('code'), redirect_uri: 'https://ailleurs.invalid/retour')
end

Quand('un second client du test échange ce code') do
  @exchange = client_declared_as(FakeFranceConnect::Clients::SECONDARY_ID).exchange(@returned.fetch('code'))
end

Quand('le faux vieillit ses codes de {int} secondes') do |seconds|
  @france_connect.age_authorization_codes(seconds)
end

Quand('le faux vieillit ses jetons d\'accès de {int} secondes') do |seconds|
  @france_connect.age_access_tokens(seconds)
end

Quand('il présente le secret en {string} seulement') do |_scheme|
  @exchange = @client.exchange_with_basic_authentication(@returned.fetch('code'))
end

Alors('\\/token le refuse') do
  expect(@exchange.status).to be >= 400
end

Alors('l\'ID Token porte {string} à {string}') do |claim, value|
  expect(@client.unseal(@tokens.fetch('id_token'))[claim]).to eq(value)
end

Alors('l\'ID Token porte {string} à {string} seul') do |claim, value|
  expect(@client.unseal(@tokens.fetch('id_token'))[claim]).to eq([value])
end

# Only the procedure's private key opens it: another key of the same type does
# not, and the JWE is therefore addressed to it and to nobody else.
Alors('seule la clé privée de la démarche ouvre l\'id_token') do
  expect(@client.decrypted(@tokens.fetch('id_token'))).to be_present
  expect { JWE.decrypt(@tokens.fetch('id_token'), OpenSSL::PKey::RSA.generate(2048)) }
    .to raise_error(StandardError)
end

Alors('le JWT intérieur est signé par une clé du JWKS du faux') do
  expect(@client.unseal(@tokens.fetch('id_token'))).to be_a(Hash)
end

Alors('il porte iss, sub, aud, exp, iat, nonce et acr') do
  claims = @client.unseal(@tokens.fetch('id_token'))

  expect(claims.keys).to include(*ID_TOKEN_CLAIMS)
  expect(claims).to include('iss' => @issuer, 'aud' => @client.client_id)
  expect(claims.fetch('exp') - claims.fetch('iat')).to eq(60)
end

Alors('il ne porte pas {string}') do |claim|
  expect(@client.unseal(@tokens.fetch('id_token'))).not_to have_key(claim)
end

Quand('il appelle \\/userinfo') do
  @userinfo = @client.userinfo(@tokens.fetch('access_token'))
end

Quand('le client appelle \\/userinfo avec un jeton d\'accès inconnu') do
  @userinfo = @client.userinfo(SecureRandom.hex(32))
end

Alors('\\/userinfo le refuse') do
  expect(@userinfo.status).to eq(401)
end

Alors('la réponse est en {string}') do |type|
  expect(@userinfo.headers['Content-Type']).to include(type)
end

Alors('le JWT déchiffré porte exactement sub, given_name, family_name, birthdate, gender et birthplace') do
  expect(@client.unseal(@userinfo.body).keys).to contain_exactly(*DECLARED_CLAIMS)
end

Alors('le JWT déchiffré porte en plus {string} égal au {string}') do |added, mirrored|
  claims = @client.unseal(@userinfo.body)

  expect(claims.keys).to contain_exactly(*DECLARED_CLAIMS, added)
  expect(claims.fetch(added)).to eq(claims.fetch(mirrored))
end

Quand('le client s\'identifie deux fois comme {string}') do |key|
  @subjects = Array.new(2) { subject_of(@client, key) }
end

Alors('les deux sub sont égaux, de {int} caractères hexadécimaux suivis de {string}') do |length, suffix|
  expect(@subjects.uniq.size).to eq(1)
  expect(@subjects.first).to match(/\A\h{#{length}}#{suffix}\z/)
end

Alors('ils ne ressemblent à aucun identifiant eIDAS') do
  expect(@subjects.first).not_to include('/')
end

Quand('un second client du test s\'identifie comme {string}') do |key|
  @other_subject = subject_of(client_declared_as(FakeFranceConnect::Clients::SECONDARY_ID), key)
end

Alors('son sub diffère de celui du premier') do
  expect(@other_subject).not_to eq(@subjects.first)
end

Quand('le client lit le JWKS') do
  @key_set_before = @client.published_kids
end

Quand('le faux change de clé de signature') do
  @france_connect.rotate_signing_key
end

Alors('le kid du jeton est absent du JWKS lu avant la rotation') do
  @kid = @client.signing_kid(@tokens.fetch('id_token'))

  expect(@key_set_before).not_to include(@kid)
end

Alors('il est présent dans le JWKS relu après elle, et sa signature s\'y vérifie') do
  expect(@client.published_kids).to include(@kid)
  expect(@client.unseal(@tokens.fetch('id_token'))).to include('sub')
end

Quand('il se déconnecte vers l\'adresse déclarée') do
  @logout_state = SecureRandom.hex(8)
  @reponse = @client.end_session('id_token_hint' => hint, 'state' => @logout_state,
    'post_logout_redirect_uri' => declared_logout_url)
end

Alors('le navigateur est redirigé vers cette adresse avec son state') do
  expect(@reponse.status).to eq(302)
  expect(@reponse.headers['Location']).to start_with(declared_logout_url)
  expect(URI.decode_www_form(URI.parse(@reponse.headers['Location']).query).to_h)
    .to include('state' => @logout_state)
end

Alors('le faux affiche la page de déconnexion, sans rediriger') do
  expect(@reponse.status).to eq(200)
  expect(@reponse.body).to include('Vous êtes bien déconnecté')
end

Quand('il se déconnecte vers une adresse non déclarée') do
  @reponse = @client.end_session('id_token_hint' => hint,
    'post_logout_redirect_uri' => 'https://ailleurs.invalid/parti')
end

Quand('il se déconnecte avec un paramètre inconnu') do
  @reponse = @client.end_session('id_token_hint' => hint, 'fantaisie' => 'oui')
end

Quand('il se déconnecte avec un id_token_hint illisible') do
  @reponse = @client.end_session('id_token_hint' => 'ceci.nest.pas.un.jwt')
end

Quand('il se déconnecte sans id_token_hint') do
  @reponse = @client.end_session({})
end

def procedure_url = ENV.fetch('URL_OOTS_FRANCE')

def declared_logout_url = "#{procedure_url}/demo/franceconnect/retour_deconnexion"

def hint = @client.decrypted(@tokens.fetch('id_token'))

def client_declared_as(client_id)
  FranceConnectClient.new(
    issuer: ENV.fetch('URL_FAUX_FRANCE_CONNECT'), client_id: client_id,
    client_secret: FakeFranceConnect::Clients::SECRETS.fetch(client_id),
    redirect_uri: "#{procedure_url}/demo/franceconnect/retour_connexion",
    private_key_jwk: Settings.france_connect_private_key_jwk,
  )
end

# The three pages, walked as a browser walks them: the country, an identity of
# that country, the consent.
def identify(client, key, **overrides)
  client.authorize(**overrides)
  client.choose_country('DK')
  client.choose_identity(key)
  client.confirm

  client.returned
end

def subject_of(client, key)
  returned = identify(client, key)
  tokens = JSON.parse(client.exchange(returned.fetch('code')).body)

  client.unseal(tokens.fetch('id_token')).fetch('sub')
end
