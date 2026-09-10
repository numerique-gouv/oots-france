# The account `db/seeds.rb` creates outside production, and that `rails db:seed`
# put in the *server's* database — the development one, which is not the
# scenario's. It is the only account these scenarios can open.
COMPTE_DEMO = { email: 'admin@example.com', password: 'Administration-2026' }.freeze

Étantdonné('l\'administrateur de démonstration connecté à l\'espace d\'administration') do
  @navigateur = DemoBrowser.new(procedure_url)
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))

  # Said here rather than left to fail further on: without the server's
  # `db:seed`, every following step would fail on the login page, which names
  # the symptom and not the cause.
  expect(@navigateur.body).not_to include(I18n.t('admin.sessions.new.submit')),
    "Connexion refusée pour #{COMPTE_DEMO.fetch(:email)} : la base du serveur n'a pas été peuplée " \
    'par `rails db:seed`. Voir docs/test_e2e.md.'
end

Quand('l\'administrateur ouvre la démarche de démonstration') do
  @navigateur.visit('/admin/demo')
end

Quand('il clique sur le bouton de la cinématique européenne') do
  @navigateur.start_identification
end

Alors('l\'administrateur arrive sur la page de choix du pays') do
  expect(@navigateur.title).to eq('Choose your country')
end

Quand('l\'administrateur choisit le pays {string}') do |code|
  @navigateur.choose('country', code)
end

Quand('l\'administrateur choisit l\'identité de test {string}') do |cle|
  @navigateur.choose('identity', cle)
end

Quand('l\'administrateur consent à la transmission de ses données') do
  @navigateur.choose('consent', 'yes')
end

# The whole flow, for the scenarios that are about what comes after it.
Quand('l\'administrateur s\'identifie avec l\'identité de test {string}') do |cle|
  @navigateur.visit('/admin/demo')
  @navigateur.start_identification
  @navigateur.choose('country', 'DK')
  @navigateur.choose('identity', cle)
  @navigateur.choose('consent', 'yes')
end

Alors('l\'administrateur arrive sur le formulaire de demande de bourse') do
  expect(@navigateur.current_url).to end_with('/admin/demo/demande')
  expect(@navigateur.title).to eq(I18n.t('admin.demo.grant_requests.show.title'))
end

Alors('le formulaire affiche {string} : {string}') do |intitule, valeur|
  expect(@navigateur.rows).to include(intitule => valeur)
end

# CA4: the attributes of the identity are shown, never typed.
Alors('le formulaire n\'a aucun champ de saisie') do
  expect(Nokogiri::HTML(@navigateur.body).css('main input, main select, main textarea')).to be_empty
end

# The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
# showing it beside a missing eIDAS identifier would invite taking it for one.
Alors('le formulaire n\'affiche pas le pseudonyme que FranceConnect+ a donné à l\'usager') do
  expect(@navigateur.body).not_to match(/\h{64}v1/)
end

Alors('le formulaire n\'affiche ni le sexe ni le lieu de naissance') do
  expect(@navigateur.rows.keys).not_to include(
    I18n.t('admin.demo.grant_requests.attributes.gender'),
    I18n.t('admin.demo.grant_requests.attributes.place_of_birth'),
  )
end

Quand('il se déconnecte de l\'espace d\'administration') do
  @navigateur.sign_out
end

Alors('FranceConnect+ le ramène sur la page de déconnexion de la démarche') do
  expect(@navigateur.current_url).to include('/demo/franceconnect/retour_deconnexion')
  expect(@navigateur.title).to eq(I18n.t('france_connect.retour_deconnexion.title'))
  expect(@navigateur.body).to include('session FranceConnect+ est close')
end

Quand('il se reconnecte à l\'espace d\'administration') do
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))
end

Quand('il ouvre le formulaire de demande de bourse') do
  @navigateur.visit('/admin/demo/demande')
end

Alors('l\'administrateur arrive sur la page d\'accueil de la démarche de démonstration, sans identité') do
  expect(@navigateur.current_url).to end_with('/admin/demo')
end
