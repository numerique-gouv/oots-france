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
  visit admin_journal_conversations_path
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
  visit admin_journal_conversation_path(conversation_named(nationality).conversation_id)
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
  expect(page).to have_text('Adresse ou mot de passe incorrect.')
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

# The one event no exchange carries: a caller turned away before anything was
# opened. Both directions have a row now, so this is what the journal holds and
# the conversations listing, by construction, cannot.
Étantdonné("une requête refusée avant qu'aucun échange soit ouvert") do
  @exchange = 'requeteur-econduit'
  create(:audit_event, event_type: 'request_refused', conversation_id: nil,
    evidence_requester_id: @exchange, detail: 'Le bénéficiaire doit être renseigné')
end

Étantdonné("un échange reçu d'un autre État membre") do
  @exchange = 'echange-recu'
  create(:conversation, :delivered, incoming: true, conversation_id: @exchange,
    country_code: nil, procedure_code: ProcedureCode::SYSTEM_CHECK)
end

Étantdonné('un échange concernant Sophie Dupont') do
  @exchange = 'echange-de-sophie'
  create(:audit_event, :about_sophie, conversation_id: @exchange)
end

Quand("j'ouvre le journal des échanges") do
  visit admin_journal_root_path
end

Quand('je recherche la personne {string} {string} née le {string}') do |family_name, given_name, date_of_birth|
  visit admin_journal_subjects_path(family_name:, given_name:, date_of_birth:)
end

Alors('je vois cet échange dans le journal') do
  expect(page).to have_text(@exchange)
end

Alors('je vois ce refus dans le journal') do
  expect(page).to have_text(@exchange)
end

Alors('je vois cet échange avec le sens {string}') do |direction|
  ligne = find('tbody tr', text: @exchange)

  expect(ligne).to have_text(direction)
end

Alors('je ne le vois pas dans la liste des conversations') do
  visit admin_journal_conversations_path

  expect(page).to have_text(I18n.t('admin.journal.conversations.index.title'))
  expect(page).to have_no_text(@exchange)
end
