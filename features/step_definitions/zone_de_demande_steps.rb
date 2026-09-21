# The address of the zone: the button posts to it, and the waiting re-asks it.
# Both are intercepted, which is the whole reason the pattern names no method —
# one scenario is about a click whose own answer is lost being retried as an
# interrogation, and telling the two apart is what it has to prove.
ZONE_ADDRESS = '*/admin/demo/demande*'.freeze

# What an answer replaces, and what says which outcome is on screen.
BODY = '.demo-request__body'.freeze

# Set on the waiting by the scenario and read back after an answer: `innerHTML`
# replaced takes it with it, a `splice` that abstains leaves it. A `data-`
# nothing in the application reads, and not the `data-outcome` the controller
# compares.
MARK = 'the-same-waiting'.freeze

# Set on the window when the page is arrived at, and read back to say a zone was
# spliced into rather than navigated away from: a reload loses it.
PAGE_MARK = 'not-reloaded'.freeze

# The element an answer never replaces — it carries the controller and the
# announced region — and the one the zone's contents live inside.
ZONE = '.demo-request'.freeze

# Set on that element when the page is arrived at, and read back after an answer
# has changed the zone: `innerHTML` replaced leaves the element, `outerHTML`
# would take it away along with what announces it.
ZONE_MARK = 'the-same-zone'.freeze

# What the zone leaves between two interrogations. Waited past, to say that no
# other one went out — the absence of a request cannot be waited *for*.
INTERVAL = 2

# How many answers in a row the zone may fail to get before it says so, and so
# how long giving up takes: three interrogations an interval apart, which is
# longer than `Capybara.default_max_wait_time` and has to be said here.
ATTEMPTS = 3
GIVING_UP = INTERVAL * (ATTEMPTS + 2)

# The document the correspondent's delivery files against the exchange, which is
# what settles the outcome whatever the contract still says.
EVIDENCE = "%PDF-1.4\ndrapeau".b

# The two requirements `eb_requirements_t1_fr` publishes, in the order the page
# renders their cards — which is how a scenario names the one it clicks, the
# doubled directories answering both with the same evidence type and the same
# provider.
REQUIREMENTS = { 'première' => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
                 'seconde' => '2d21a531-d30e-4e30-9e5e-b53d6aedb30b' }.freeze

# The exchange the contract opens for the second requirement, so that two clicks
# are two exchanges rather than one read twice.
SECOND_EXCHANGE = 'aaaaaaaa-0000-4000-8000-000000000002'.freeze

Étantdonné('les annuaires et le contrat de la démarche doublés') do
  # First of all, and not by taste: it is what pins `Settings.oots_france_url`,
  # the root every double of the contract below is mounted on.
  stub_browser_france_connect

  stub_code_list
  stub_directory_resolution
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
  stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
  stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  stub_oots_france_public_keys
  stub_evidence_request
  stub_exchange_state
end

# The whole European flow as the browser walks it: the departure is clicked, the
# authorization endpoint sends the browser back, and the return is accepted on a
# `state` and a `nonce` this scenario never wrote.
Étantdonné("l'usager identifié sur la page des justificatifs") do
  visit admin_demo_root_path
  sign_in_with('fake')

  expect(page).to have_button(press_label)
  mark_the_page
end

Étantdonné('la soumission de la demande retenue devant le navigateur') do
  zone_requests.hold
end

# The procedure rests on two requirements here where the `Contexte` doubles one,
# and the page is asked for again so that both cards stand on it. The journey
# the sign-in opened is untouched: what a card is clicked under is read from it,
# never written by a click.
Étantdonné('les deux exigences de la démarche affichées') do
  stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_t1_fr')
  stub_evidence_request_for(REQUIREMENTS.fetch('seconde'), SECOND_EXCHANGE)
  stub_exchange_state(SECOND_EXCHANGE, statut: 'pending')

  visit admin_demo_documents_path

  expect(page).to have_css(ZONE, count: REQUIREMENTS.size)
end

# Both clicks held before either is answered: the second leaves while the first
# is still out, which is the race itself.
Étantdonné('les soumissions des deux cartes retenues devant le navigateur') do
  zone_requests.hold.hold
end

Étantdonné('la soumission de la demande et les deux requêtes suivantes coupées devant le navigateur') do
  zone_requests.cut.cut.cut
end

# Clicked and answered before anything is planned for what follows: the zone
# schedules its first interrogation on that answer, so a treatment armed any
# earlier would meet the submission instead.
Étantdonné('une demande en cours') do
  click_button press_label

  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  wait_until_registered
  mark_the_waiting
end

Étantdonné('la première interrogation laissée passer, la deuxième retenue devant le navigateur') do
  zone_requests.pass.hold
end

Étantdonné('la première interrogation coupée, la deuxième répondue sans l\'en-tête "Deferred-Fragment" devant le navigateur') do
  zone_requests.cut.answer(status: 502, body: BAD_GATEWAY_PAGE)
end

Étantdonné('les trois interrogations suivantes coupées devant le navigateur') do
  zone_requests.cut.cut.cut
end

Étantdonné('une interrogation retenue devant le navigateur') do
  zone_requests.hold
end

Quand("l'usager clique sur {string}") do |label|
  click_button label
end

Quand("l'usager clique sur le bouton de la {word} carte") do |rank|
  within(card_zone(rank)) { click_button press_label }
end

Quand('la soumission retenue est libérée') do
  zone_requests.release
end

# In the order they were clicked, which the double holds them in: the second
# answer is then the one that comes back last.
Quand("les deux soumissions retenues sont libérées dans l'ordre des clics") do
  2.times { zone_requests.release }
end

Quand("l'interrogation retenue est libérée") do
  zone_requests.release
end

# Blocks until the browser has asked, which is what makes the next assertion
# about a request that has actually gone out rather than one that may yet.
Quand('la zone interroge son adresse') do
  zone_requests.held
end

Quand('deux interrogations de suite n\'obtiennent aucune réponse exploitable') do
  wait_until_seen(2)
end

Quand('le justificatif est remis') do
  Demo::Request.sole.receive_evidence!(EVIDENCE)
end

Quand("l'usager recharge la page des justificatifs") do
  page.refresh
  mark_the_page
end

Quand('le compte de l\'administrateur est supprimé') do
  @administrator.destroy!
end

# The one thing the server cannot say, so the one the browser says of itself.
# Waited for rather than asserted: three interrogations two seconds apart is
# what precedes it.
Quand('la zone renonce à joindre le service') do
  # `normalize_ws`: the wording places a link mid-sentence, so the rendering
  # breaks it over three lines where the translation has one.
  expect(page).to have_text(disconnected_sentence, wait: GIVING_UP, normalize_ws: true)
end

Quand("l'usager suit le lien {string}") do |label|
  click_link label
end

Alors("la zone annonce qu'elle attend") do
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  expect(page).to have_css("#{BODY}[data-outcome='pending']", visible: :all)
  mark_the_waiting
end

Alors("la zone de la {word} carte annonce qu'elle attend") do |rank|
  within(card_zone(rank)) do
    expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
    expect(page).to have_css("#{BODY}[data-outcome='pending']", visible: :all)
  end
end

# Each on the request its own click opened, whichever answer came back last:
# what the page renders a zone on is read from the register, under the journey
# and the requirement, and a click writes nothing a neighbour could overwrite.
#
# The register is waited on first, and not out of caution: the zone announces
# its waiting the instant the button is clicked, before any answer has come
# back, so the screen alone would let this step pass over a submission still in
# flight — and the reload that follows would then render on one request.
Alors("les deux zones annoncent qu'elles attendent") do
  wait_until_registered(REQUIREMENTS.size)

  expect(page).to have_css("#{BODY}[data-outcome='pending']", count: REQUIREMENTS.size, visible: :all)
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'), count: REQUIREMENTS.size)
end

Alors('la zone annonce toujours la même attente') do
  expect(page).to have_text(I18n.t('components.demo_request_zone.loading'))
  expect(page).to have_css("#{BODY}[data-scenario-mark='#{MARK}']", visible: :all)
end

# Neither of its two labels: asking again after a refusal is the same button
# under another word, and giving up offers neither.
Alors('la page n\'affiche aucun bouton de demande') do
  expect(page).to have_no_button(I18n.t('components.demo_request_zone.submit'))
  expect(page).to have_no_button(I18n.t('components.demo_request_zone.retry'))
end

Alors('la page affiche le bouton {string}') do |label|
  expect(page).to have_button(label)
end

Alors('la page affiche le lien {string}') do |label|
  expect(page).to have_link(label)
end

Alors('la page des justificatifs est toujours affichée') do
  expect(page).to have_current_path(admin_demo_documents_path)
end

# Chapter-free and structural: the element that holds the announced region is
# the one an answer must not replace, and a zone rebuilt whole would lose it
# along with the controller that keeps asking.
Alors("la zone n'a pas été remplacée, seulement son contenu") do
  expect(page).to have_css("#{ZONE}[data-scenario-zone='#{ZONE_MARK}']", visible: :all)
end

Alors("la page des justificatifs n'a pas été rechargée") do
  expect(page).to have_current_path(admin_demo_documents_path)
  expect(page.evaluate_script('window.pageMark')).to eq(PAGE_MARK)
end

Alors("le contrat n'a reçu aucune demande") do
  expect(contract_demands).to be_empty
end

# Waited for: releasing the submission hands it on asynchronously, so the
# demand reaches the contract after this step has begun.
Alors('le contrat a reçu la demande') do
  wait_until('Le contrat n\'a reçu aucune demande.') { contract_demands.any? }
end

# Asked before the held submission is released, which is what it proves: the
# second click does not wait on the first answer.
Alors('le contrat a reçu la demande de la {word} carte') do |rank|
  asked = requirement_uri(REQUIREMENTS.fetch(rank))

  wait_until("Le contrat n'a reçu aucune demande pour la #{rank} exigence.") do
    contract_demands.any? { |demand| Rack::Utils.parse_nested_query(demand.uri.query.to_s)['idExigence'] == asked }
  end
end

# One tick at a time: an absence is waited past rather than waited for, so the
# interval is let by and what went out is counted again.
Alors('aucune autre interrogation ne part') do
  gone = zone_requests.seen.size
  sleep INTERVAL + 1

  expect(zone_requests.seen.size).to eq(gone)
end

# What a lost click is retried as. Chapter 4.4 §4.1 makes a click a new request
# — « a new unique request MUST be issued » — so sending it again would open a
# second exchange while the first is still under way; consulting its address is
# free to be repeated.
Alors('les essais qui suivent la soumission sont des interrogations') do
  wait_until_seen(3)
  attempts = zone_requests.seen.pluck(:method)

  # `uniq` and not the `all` matcher: Capybara's own `all` is in this World and
  # is what the bare name resolves to.
  expect(attempts.first).to eq('POST')
  expect(attempts.drop(1).uniq).to eq(%w[GET])
end

def zone_requests = intercepted_requests(pattern: ZONE_ADDRESS)

# The card a step names, by its rank among those the page offers a button on.
def card_zone(rank) = all(ZONE, count: REQUIREMENTS.size)[REQUIREMENTS.keys.index(rank)]

def press_label = I18n.t('components.demo_request_zone.submit')

# The sentence alone, the wording carrying a link the translation places.
def disconnected_sentence
  ActionController::Base.helpers.strip_tags(
    I18n.t('components.demo_request_zone.disconnected_html', reload: I18n.t('components.demo_request_zone.reload')),
  )
end

def mark_the_waiting
  page.execute_script("document.querySelector('#{BODY}').dataset.scenarioMark = '#{MARK}'")
end

# Both marks are posed together, the page and the element the answers splice
# into: a reload loses the first, and a replacement of the element the second.
def mark_the_page
  page.execute_script("window.pageMark = '#{PAGE_MARK}'")
  page.execute_script("document.querySelector('#{ZONE}').dataset.scenarioZone = '#{ZONE_MARK}'")
end

# The click is answered once the register carries the request: from then on,
# what the zone asks for is its state. Counted, because a scenario clicking two
# cards has to know both submissions arrived and not just the first.
def wait_until_registered(count = 1)
  wait_until(-> { "#{Demo::Request.count} demande(s) enregistrée(s) sur #{count} : une soumission n'a pas abouti." }) do
    Demo::Request.count >= count
  end
end

# The requests the double has treated, waited for by count: each is an interval
# after the one before, and Capybara's own waiting governs elements only.
def wait_until_seen(count)
  wait_until(-> { "La zone n'a fait que #{zone_requests.seen.size} requête(s) sur #{count} attendue(s)." },
    seconds: INTERVAL * (count + 2)) { zone_requests.seen.size >= count }
end

# What Capybara does for an element, for everything else this suite waits on: a
# browser and a server work in their own threads, and what they have done is
# true a moment after the step that caused it.
def wait_until(complaint, seconds: Capybara.default_max_wait_time)
  limit = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

  until yield
    raise(complaint.respond_to?(:call) ? complaint.call : complaint) if
      Process.clock_gettime(Process::CLOCK_MONOTONIC) > limit

    sleep 0.05
  end
end
