# Les adjectifs s'accordent avec « échange », masculin, tel que les scénarios
# les écrivent.
COUNTRIES = {
  'finlandais' => 'FI',
  'allemand' => 'DE',
}.freeze

# The way in a development machine and the suites have, which presents no
# credentials to ProConnect: the button the login page offers in development
# and test alone. The suite's database is never seeded, so the step names the
# agent itself where the seed would have.
Étantdonné("un administrateur connecté à l'espace d'administration") do
  Administrator.appoint(Admin::DevelopmentSessionsController.agent_email)
  sign_in_without_pro_connect
end

Étantdonné("un agent connecté à l'espace d'administration") do
  sign_in_without_pro_connect
end

Quand('son adresse est nommée administrateur') do
  Administrator.appoint(Admin::DevelopmentSessionsController.agent_email)
end

Quand("l'agent ouvre l'accueil de l'espace d'administration") do
  visit admin_root_path
end

Quand("l'agent ouvre l'accueil des annuaires") do
  stub_code_list
  stub_directory_resolution
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_catalogue')
  visit admin_common_services_root_path
end

Quand("l'agent ouvre l'écran du choix de la version de la démarche") do
  visit admin_demo_root_path
end

# Each a page the agent reaches by its address, none of them being offered.
RESERVED_PAGES = {
  'le journal des événements' => -> { admin_journal_root_path },
  "la fiche de l'échange allemand" => -> { admin_journal_exchange_path(exchange_named('allemand').exchange_id) },
  'la recherche par personne' => lambda {
    admin_journal_subjects_path(family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25')
  },
  'le tableau de bord des jobs' => -> { admin_jobs_path },
  "la page des points d'accès" => -> { admin_common_services_access_points_path },
}.freeze

Quand("l'agent ouvre {string} par son adresse") do |page_name|
  visit instance_exec(&RESERVED_PAGES.fetch(page_name))
end

# No form offers it: the request a crafted page, or a stale tab, would send.
Quand("l'agent demande un test de connectivité par son adresse") do
  page.driver.submit :post, admin_common_services_connectivity_tests_path, {}
end

Alors("le journal des événements s'affiche") do
  expect(page).to have_current_path(admin_journal_root_path)
  expect(page).to have_css('h1', text: I18n.t('admin.journal.events.index.title'))
end

Alors("la page dit qu'elle est réservée aux administrateurs nommés") do
  expect(page).to have_css('h1', text: I18n.t('admin.restricted_access.show.title'))
  expect(page).to have_text(I18n.t('admin.restricted_access.show.body').squish)
end

Alors("aucun test de connectivité n'est enregistré") do
  expect(ConnectivityTest.count).to eq(0)
end

Alors('la page offre les tuiles {string}') do |tiles|
  expect(page.all('.fr-tile__title').map { |tile| tile.text.strip }).to eq(tiles.split(' et '))
end

HEADER_ENTRIES = %w[directories journal jobs demo].map { |entry| I18n.t("layouts.entete.#{entry}") }.freeze

Alors("l'en-tête offre les liens {string} seulement") do |links|
  offered = links.split(/, | et /)

  HEADER_ENTRIES.each do |entry|
    if offered.include?(entry)
      expect(page).to have_css('header a', text: entry)
    else
      expect(page).to have_no_css('header a', text: entry)
    end
  end
end

Alors("la page offre la carte des points d'accès") do
  expect(page).to have_css('.fr-tile__title', text: I18n.t('admin.common_services.access_points.index.title'))
end

Alors("la page n'offre pas la carte des points d'accès") do
  expect(page).to have_css('.fr-tile__title', count: 3)
  expect(page).to have_no_css('.fr-tile__title', text: I18n.t('admin.common_services.access_points.index.title'))
end

Quand("l'administrateur s'identifie par ProConnect") do
  sign_in_through_pro_connect
end

Quand("un agent s'identifie par ProConnect avec l'adresse {string}") do |email|
  sign_in_through_pro_connect(email:)
end

Étantdonné('ProConnect refuse la prochaine identification') do
  BROWSER_PRO_CONNECT.refuse_next
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
  stub_code_list
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
  visit admin_root_path
  click_link I18n.t('layouts.entete.demo')
end

# The screen the line is chosen on, in the order France prefers them.
Alors("l'écran du choix de la version affiche les cartes {string} puis {string}") do |premiere, seconde|
  expect(page).to have_current_path(admin_demo_root_path)
  expect(page.all('.fr-card__title').map { |titre| titre.text.strip }).to eq([premiere, seconde])
end

Quand("l'administrateur choisit la carte {string} de l'écran du choix de la version") do |carte|
  click_link carte
end

Alors("la page d'accueil de la démarche de démonstration s'affiche") do
  expect(page).to have_current_path(admin_demo_home_path(version: 'v2.0'))
  expect(page).to have_css('h1', text: "🇫🇷 #{ProcedureCode::STUDY_FINANCING}")
  expect(page).to have_css('h1 .directory-value', text: 'Apply for funding for higher education')
end

Étantdonné('le faux FranceConnect+ déclaré par la France') do
  declare_france_connect(fake_france_connect)
end

# One button per FranceConnect+ declared, and a button and not a link: starting
# the flow writes the `state` and the `nonce` its return will be checked
# against, and a replayed GET would overwrite those of a flow under way.
Alors("la page propose de s'identifier avec une identité d'un autre État membre") do
  expect(page).to have_css('h2', text: I18n.t('admin.demo.home.show.sign_in.heading'))
  expect(page).to have_button(I18n.t('admin.demo.home.show.france_connect.fake.button'), count: 1)
  expect(page).to have_css("form[action='#{admin_demo_identification_path(version: 'v2.0')}'][method='post']")
end

Quand('un visiteur ouvre le tableau de bord des jobs') do
  visit admin_jobs_path
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
  expect(page).to have_button("S'identifier avec ProConnect")
end

# CA1: the button, its link, the sentence, and no field to type anything in.
Alors("la page de connexion propose de s'identifier avec ProConnect aux adresses en {string}") do |domains|
  expect(page).to have_button("S'identifier avec ProConnect")
  expect(page).to have_link("Qu'est-ce que ProConnect ?", href: 'https://www.proconnect.gouv.fr/')
  expect(page).to have_css('main p',
    text: "L'espace d'administration est réservé aux agents dont l'adresse est en #{domains}.")
  expect(page).to have_no_field(type: 'password')
end

Alors("la page de connexion dit que l'adresse {string} n'est pas admise") do |email|
  expect(page).to have_current_path(new_admin_session_path)
  expect(page).to have_css('.fr-alert--error', text: "vous vous êtes identifié avec « #{email} »")
end

Alors("l'en-tête affiche l'adresse {string}") do |email|
  expect(page).to have_css('.fr-header__tools-links', text: email)
end

Alors('la page de connexion dit {string}') do |message|
  expect(page).to have_current_path(new_admin_session_path)
  expect(page).to have_css('.fr-alert', text: message)
end

def exchange_named(nationality)
  Exchange.find_by!(country_code: COUNTRIES.fetch(nationality))
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

Quand(/^(?:un visiteur|l'administrateur|l'agent|il) ouvre le journal des événements$/) do
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
