# Les adjectifs s'accordent avec « échange », masculin, tel que les scénarios
# les écrivent.
COUNTRIES = {
  'finlandais' => 'FI',
  'allemand' => 'DE',
}.freeze

# Created in a step and not once for the whole run: `cucumber-rails` cleans the
# database around every scenario, so an account posted beforehand would be gone.
Étantdonné("un compte d'administrateur") do
  @administrator = create(:administrator)
end

Étantdonné("un administrateur connecté à l'espace d'administration") do
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

# Ouverte depuis le menu, et non par son adresse : c'est l'entrée elle-même que
# [OOTS-178](https://linear.app/pole-api/issue/OOTS-178) demande de vérifier.
Quand("l'administrateur suit l'entrée « Démo » du menu") do
  stub_code_list(procedures: { ProcedureCode::STUDY_FINANCING => CodeListStubs::STUDY_FINANCING_LABEL })
  visit admin_root_path
  click_link I18n.t('layouts.entete.demo')
end

Alors("la page d'accueil de la démarche de démonstration s'affiche") do
  expect(page).to have_current_path(admin_demo_root_path)
  expect(page).to have_text(I18n.t('admin.demo.home.show.portal'))
  expect(page).to have_css(
    'h1',
    exact_text: "#{ProcedureCode::STUDY_FINANCING} — #{CodeListStubs::STUDY_FINANCING_LABEL}",
  )
end

# A button and not a link: starting the flow writes the `state` and the `nonce`
# its return will be checked against, and a replayed GET would overwrite those
# of a flow under way.
Alors("la page propose de s'identifier avec une identité d'un autre État membre") do
  expect(page).to have_button(I18n.t('admin.demo.home.show.sign_in'))
  expect(page).to have_css("form[action='#{admin_demo_identification_path}'][method='post']")
end

Quand('un visiteur ouvre le tableau de bord des jobs') do
  visit admin_jobs_path
end

Quand('l\'administrateur se connecte avec un mot de passe incorrect') do
  sign_in('un-autre-mot-de-passe')
end

Quand('l\'administrateur se déconnecte') do
  click_button 'Se déconnecter'
end

Quand("l'administrateur ouvre la fiche de l'échange {word}") do |nationality|
  visit admin_journal_exchange_path(exchange_named(nationality).exchange_id)
end

Quand("il filtre sur l'échange {word}") do |nationality|
  fill_in I18n.t('admin.journal.attributes.exchange_id'), with: exchange_named(nationality).exchange_id
  click_button I18n.t('admin.journal.filtre.submit')
end

# The listing abbreviates both identifiers — two UUIDs a row would leave no
# room for anything else — and carries the whole one in the link's title. That
# is what a scenario has to look at.
Alors("le journal affiche les événements de l'échange {word}") do |nationality|
  expect(page).to have_css("a[title='#{exchange_named(nationality).exchange_id}']")
end

Alors("le journal n'affiche pas les événements de l'échange {word}") do |nationality|
  expect(page).to have_no_css("a[title='#{exchange_named(nationality).exchange_id}']")
end

Alors("la page n'affiche pas l'échange {word}") do |nationality|
  expect(page).to have_no_text(exchange_named(nationality).exchange_id)
end

Alors("la fiche affiche le code d'erreur {string}") do |code|
  expect(page).to have_text(code)
end

Alors("la fiche affiche la raison de l'échec de l'échange {word}") do |nationality|
  expect(page).to have_text(exchange_named(nationality).error_description)
end

Alors('la page de connexion s\'affiche') do
  expect(page).to have_current_path(new_admin_session_path)
  expect(page).to have_button('Se connecter')
end

Alors('la page de connexion dit que les identifiants sont refusés') do
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

Quand(/^(?:un visiteur|l'administrateur|il) ouvre le journal des événements$/) do
  visit admin_journal_root_path
end

Quand('l\'administrateur recherche la personne {string} {string} née le {string}') do |family_name, given_name, date_of_birth|
  visit admin_journal_subjects_path(family_name:, given_name:, date_of_birth:)
end

# Whole in the title, abbreviated in the text — and not always a link: an event
# may name an exchange this side never opened, which reads as plain text.
Alors('le journal affiche cet échange') do
  expect(page).to have_css("[title='#{@exchange}']", visible: :all)
end

Alors('le journal affiche ce refus') do
  expect(page).to have_text(@exchange)
end

Alors('la fiche affiche le sens {string}') do |direction|
  expect(page).to have_text(direction)
end

Alors('le refus ne nomme ni échange ni conversation') do
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

Quand("l'administrateur ouvre la fiche de cette conversation") do
  visit admin_journal_conversation_path(@conversation)
end

Alors('la fiche affiche les deux échanges, chacun avec ses événements') do
  @echanges.each { |echange| expect(page).to have_text(echange.exchange_id) }

  expect(page).to have_table(count: @echanges.size)
end

Quand("l'administrateur ouvre la fiche de cet échange") do
  visit admin_journal_exchange_path(@exchange)
end
