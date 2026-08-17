COUNTRIES = {
  'finlandaise' => 'FI',
  'allemande' => 'DE',
}.freeze

# Created in a step and not once for the whole run: `cucumber-rails` cleans the
# database around every scenario, so an account posted beforehand would be gone.
Étantdonné("un compte d'administration") do
  @administrator = create(:administrator)
end

Étantdonné("je suis connecté à l'espace d'administration") do
  sign_in(@administrator.password)
end

Étantdonné('une conversation délivrée avec la Finlande') do
  create(:conversation, :delivered, country_code: COUNTRIES.fetch('finlandaise'))
end

Étantdonné("une conversation en échec avec l'Allemagne") do
  create(:conversation, :failed, country_code: COUNTRIES.fetch('allemande'))
end

Quand("j'ouvre la liste des conversations") do
  visit admin_conversations_path
end

Quand("j'ouvre le tableau de bord des jobs") do
  visit admin_jobs_path
end

Quand('je me connecte avec un mot de passe incorrect') do
  sign_in('un-autre-mot-de-passe')
end

Quand('je me déconnecte') do
  click_button 'Se déconnecter'
end

Quand("j'ouvre la fiche de la conversation {word}") do |nationality|
  visit admin_conversation_path(conversation_named(nationality).conversation_id)
end

Quand("je filtre sur l'état {string}") do |state|
  select state, from: 'status'
  click_button 'Filtrer'
end

Alors("je vois la conversation {word} avec l'état {string}") do |nationality, state|
  ligne = find('tbody tr', text: conversation_named(nationality).conversation_id)

  expect(ligne).to have_text(state)
end

Alors('je ne vois plus la conversation {word}') do |nationality|
  expect(page).to have_no_text(conversation_named(nationality).conversation_id)
end

Alors("je lis le code d'erreur {string}") do |code|
  expect(page).to have_text(code)
end

Alors("je lis la raison de l'échec de la conversation {word}") do |nationality|
  expect(page).to have_text(conversation_named(nationality).error_description)
end

Alors('on me demande de me connecter') do
  expect(page).to have_current_path(new_admin_session_path)
  expect(page).to have_button('Se connecter')
end

Alors('on me dit que les identifiants sont refusés') do
  expect(page).to have_text(I18n.t('admin.sessions.refused'))
  expect(page).to have_button('Se connecter')
end

def conversation_named(nationality)
  Conversation.find_by!(country_code: COUNTRIES.fetch(nationality))
end

def sign_in(password)
  visit new_admin_session_path
  fill_in 'Adresse électronique', with: @administrator.email
  fill_in 'Mot de passe', with: password
  click_button 'Se connecter'
end
