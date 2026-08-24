# Les adjectifs s'accordent avec « échange », masculin, tel que les scénarios
# les écrivent.
COUNTRIES = {
  'finlandais' => 'FI',
  'allemand' => 'DE',
}.freeze

# Created in a step and not once for the whole run: `cucumber-rails` cleans the
# database around every scenario, so an account posted beforehand would be gone.
Étantdonné("un compte d'administration") do
  @administrator = create(:administrator)
end

Étantdonné("je suis connecté à l'espace d'administration") do
  sign_in(@administrator.password)
end

Étantdonné('un échange délivré avec la Finlande') do
  echange = create(:exchange, :delivered, country_code: COUNTRIES.fetch('finlandais'))
  create(:audit_event, event_type: 'evidence_delivered', exchange_id: echange.exchange_id,
    conversation_id: echange.conversation_id)
end

Étantdonné("un échange en échec avec l'Allemagne") do
  echange = create(:exchange, :failed, country_code: COUNTRIES.fetch('allemand'))
  create(:audit_event, event_type: 'error_received', exchange_id: echange.exchange_id,
    conversation_id: echange.conversation_id)
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

Quand("j'ouvre la fiche de l'échange {word}") do |nationality|
  visit admin_journal_exchange_path(exchange_named(nationality).exchange_id)
end

Quand("je filtre sur l'échange {word}") do |nationality|
  fill_in I18n.t('admin.journal.attributes.exchange_id'), with: exchange_named(nationality).exchange_id
  click_button I18n.t('admin.journal.filtre.submit')
end

# The listing abbreviates both identifiers — two UUIDs a row would leave no
# room for anything else — and carries the whole one in the link's title. That
# is what a scenario has to look at.
Alors("je vois les évènements de l'échange {word}") do |nationality|
  expect(page).to have_css("a[title='#{exchange_named(nationality).exchange_id}']")
end

Alors("je ne vois plus ceux de l'échange {word}") do |nationality|
  expect(page).to have_no_css("a[title='#{exchange_named(nationality).exchange_id}']")
end

Alors("je ne vois plus l'échange {word}") do |nationality|
  expect(page).to have_no_text(exchange_named(nationality).exchange_id)
end

Alors("je lis le code d'erreur {string}") do |code|
  expect(page).to have_text(code)
end

Alors("je lis la raison de l'échec de l'échange {word}") do |nationality|
  expect(page).to have_text(exchange_named(nationality).error_description)
end

Alors('on me demande de me connecter') do
  expect(page).to have_current_path(new_admin_session_path)
  expect(page).to have_button('Se connecter')
end

Alors('on me dit que les identifiants sont refusés') do
  expect(page).to have_text('Adresse ou mot de passe incorrect.')
  expect(page).to have_button('Se connecter')
end

def exchange_named(nationality)
  Exchange.find_by!(country_code: COUNTRIES.fetch(nationality))
end

def sign_in(password)
  visit new_admin_session_path
  fill_in 'Adresse électronique', with: @administrator.email
  fill_in 'Mot de passe', with: password
  click_button 'Se connecter'
end

# The one event no exchange carries: a caller turned away before anything was
# opened. Both directions have a row now, so this is what the journal holds and
# the exchange listing, by construction, cannot.
Étantdonné("une requête refusée avant qu'aucun échange soit ouvert") do
  @exchange = 'requeteur-econduit'
  create(:audit_event, event_type: 'request_refused', exchange_id: nil, conversation_id: nil,
    evidence_requester_id: @exchange, detail: 'Le bénéficiaire doit être renseigné')
end

Étantdonné("un échange reçu d'un autre État membre") do
  @exchange = '88888888-8888-8888-8888-888888888801'
  create(:exchange, :delivered, incoming: true, exchange_id: @exchange,
    country_code: nil, procedure_code: ProcedureCode::SYSTEM_CHECK)
end

Étantdonné('un échange concernant Sophie Dupont') do
  @exchange = '88888888-8888-8888-8888-888888888802'
  create(:audit_event, :about_sophie, exchange_id: @exchange)
end

Quand("j'ouvre le journal des évènements") do
  visit admin_journal_root_path
end

Quand('je recherche la personne {string} {string} née le {string}') do |family_name, given_name, date_of_birth|
  visit admin_journal_subjects_path(family_name:, given_name:, date_of_birth:)
end

# Whole in the title, abbreviated in the text — and not always a link: an event
# may name an exchange this side never opened, which reads as plain text.
Alors('je vois cet échange dans le journal') do
  expect(page).to have_css("[title='#{@exchange}']", visible: :all)
end

Alors('je vois ce refus dans le journal') do
  expect(page).to have_text(@exchange)
end

Alors('je vois cet échange avec le sens {string}') do |direction|
  expect(page).to have_text(direction)
end

Alors('il ne nomme ni échange ni conversation') do
  ligne = find('tbody tr', text: @exchange)

  expect(ligne).to have_text('—')
end

# Chapter 4.4 has one conversation cover the exchanges of a single user's
# session; the page is what gathers them, an exchange having no listing of its
# own any more.
Étantdonné("deux échanges d'un même usager") do
  @conversation = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'
  @echanges = Array.new(2) do
    echange = create(:exchange, :delivered, conversation_id: @conversation)
    create(:audit_event, event_type: 'request_sent', exchange_id: echange.exchange_id,
      conversation_id: @conversation)
    echange
  end
end

Quand("j'ouvre la conversation de cet usager") do
  visit admin_journal_conversation_path(@conversation)
end

Alors('je vois les deux échanges, chacun avec son journal') do
  @echanges.each { |echange| expect(page).to have_text(echange.exchange_id) }

  expect(page).to have_table(count: @echanges.size)
end

Quand("j'ouvre la fiche de cet échange") do
  visit admin_journal_exchange_path(@exchange)
end
