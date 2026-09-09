# The account `db/seeds.rb` creates outside production, and that `rails db:seed`
# put in the *server's* database — the development one, which is not the
# scenario's. It is the only account these scenarios can open.
COMPTE_DEMO = { email: 'admin@example.com', password: 'Administration-2026' }.freeze

Étantdonné('un exploitant connecté à la console') do
  @navigateur = DemoBrowser.new(procedure_url)
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))

  # Said here rather than left to fail further on: without the server's
  # `db:seed`, every following step would fail on the login page, which names
  # the symptom and not the cause.
  expect(@navigateur.body).not_to include(I18n.t('admin.sessions.new.submit')),
    "Connexion refusée pour #{COMPTE_DEMO.fetch(:email)} : la base du serveur n'a pas été peuplée " \
    'par `rails db:seed`. Voir docs/test_e2e.md.'
end

Quand('il ouvre la démarche de démonstration') do
  @navigateur.visit('/admin/demo')
end

Quand('il suit le bouton de la cinématique européenne') do
  @navigateur.start_identification
end

Alors('la page de choix du pays de la passerelle s\'ouvre') do
  expect(@navigateur.title).to eq('Choose your country')
end

Quand('il choisit le pays {string} sur la page de la passerelle') do |code|
  @navigateur.choose('country', code)
end

Quand('il choisit l\'identité de test {string}') do |cle|
  @navigateur.choose('identity', cle)
end

Quand('il confirme la transmission de ses données') do
  @navigateur.choose('consent', 'yes')
end

# The whole flow, for the scenarios that are about what comes after it.
Quand('il s\'identifie comme {string}') do |cle|
  @navigateur.visit('/admin/demo')
  @navigateur.start_identification
  @navigateur.choose('country', 'DK')
  @navigateur.choose('identity', cle)
  @navigateur.choose('consent', 'yes')
end

Alors('il arrive sur le formulaire de demande de bourse') do
  expect(@navigateur.current_url).to end_with('/admin/demo/demande')
  expect(@navigateur.title).to eq(I18n.t('admin.demo.grant_requests.show.title'))
end

Alors('le formulaire porte {string} à {string}') do |intitule, valeur|
  expect(@navigateur.rows).to include(intitule => valeur)
end

# CA4: the attributes of the identity are shown, never typed.
Alors('le formulaire n\'offre aucun champ de saisie') do
  expect(Nokogiri::HTML(@navigateur.body).css('main input, main select, main textarea')).to be_empty
end

# The `sub` is a pseudonym of FranceConnect+'s own, per service provider:
# showing it beside a missing eIDAS identifier would invite taking it for one.
Alors('le formulaire ne montre pas l\'identifiant que FranceConnect+ lui a donné') do
  expect(@navigateur.body).not_to match(/\h{64}v1/)
end

Alors('le formulaire ne dit ni le sexe ni le lieu de naissance') do
  expect(@navigateur.rows.keys).not_to include(
    I18n.t('admin.demo.grant_requests.attributes.gender'),
    I18n.t('admin.demo.grant_requests.attributes.place_of_birth'),
  )
end

Quand('il se déconnecte de la console') do
  @navigateur.sign_out
end

Alors('FranceConnect+ le ramène sur la page de déconnexion de la démarche') do
  expect(@navigateur.current_url).to include('/demo/franceconnect/retour_deconnexion')
  expect(@navigateur.title).to eq(I18n.t('france_connect.retour_deconnexion.title'))
  expect(@navigateur.body).to include('session FranceConnect+ est close')
end

Quand('il se reconnecte à la console') do
  @navigateur.sign_in(COMPTE_DEMO.fetch(:email), COMPTE_DEMO.fetch(:password))
end

Quand('il ouvre le formulaire de demande de bourse') do
  @navigateur.visit('/admin/demo/demande')
end

Alors('la démarche le renvoie à son accueil, sans identité') do
  expect(@navigateur.current_url).to end_with('/admin/demo')
end
