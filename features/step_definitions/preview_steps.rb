# Chapter 4.9 played end to end: a foreign requester forging both requests of
# a preview, and the user following France's address in a browser.

RETURN_ADDRESS = 'https://portail.example/retour'.freeze

def preview_flag(xml) = xml.sub(/(<rim:Slot name="PossibilityForPreview">.*?<rim:Value>)[^<]*/m, '\1true')

def with_slots(xml, slots)
  preview_flag(xml).sub('<rim:Slot name="ExplicitRequestGiven">') { "#{slots}<rim:Slot name=\"ExplicitRequestGiven\">" }
end

def string_slot(name, value)
  %(<rim:Slot name="#{name}"><rim:SlotValue xsi:type="rim:StringValueType">) +
    %(<rim:Value>#{value}</rim:Value></rim:SlotValue></rim:Slot>)
end

def journalled(description, **criteria)
  patiente_jusqu_a(description) { ServerAuditEvent.exists?(**criteria) }

  ServerAuditEvent.find_by!(**criteria)
end

def issued_error
  criteria = @request_id ? { request_id: @request_id } : { exchange_id: @exchange_id }

  journalled('la France ait répondu la prévisualisation', event_type: 'error_sent', **criteria)
end

def space_browser = @space_browser ||= DemoBrowser.new(procedure_url)

Quand('le requêteur étranger envoie une requête qui exige la prévisualisation') do
  @exchange_id = @correspondent.submit(@correspondent.request { |xml| preview_flag(xml) })
end

Quand('le requêteur étranger envoie en {string} une requête qui exige la prévisualisation') do |version|
  body = @correspondent.request(specification: EdmSpecification.find(version)) { |xml| preview_flag(xml) }

  @request_id = @correspondent.submit_on_the_earlier_line(body)
end

Alors('la France répond {string} avec l\'adresse de son espace de prévisualisation') do |code|
  expect(issued_error).to have_attributes(edm_error_code: code, preview_location: start_with(procedure_url))
end

Alors('la France répond {string} avec l\'adresse de son espace et la méthode {string}') do |code, method|
  expect(issued_error).to have_attributes(edm_error_code: code, preview_location: start_with(procedure_url))
  expect(issued_error.regrep_body).to include('PreviewMethod').and include("<rim:Value>#{method}</rim:Value>")
end

Quand('l\'usager (r)ouvre l\'espace de prévisualisation') do
  space_browser.follow_address(issued_error.preview_location)
end

Quand('l\'usager ouvre l\'espace de prévisualisation avec une adresse de retour') do
  space_browser.follow_address(
    "#{issued_error.preview_location}?returnurl=#{CGI.escape(RETURN_ADDRESS)}&returnmethod=GET",
  )
end

Alors('la page affiche le lien vers le document') do
  expect(space_browser.links("a[href$='/document']").size).to eq(1)
  @seen_document = space_browser.fetch(space_browser.links("a[href$='/document']").first)
end

Quand('l\'usager choisit {string} et valide son choix') do |label|
  decision = PreviewSession::DECISIONS.find { |one| I18n.t("preview_sessions.show.open.#{one}") == label }

  space_browser.choose('choice', decision)
end

Quand('le requêteur étranger envoie la seconde requête avec l\'adresse de l\'espace et une adresse de retour') do
  slots = string_slot('PreviewLocation', issued_error.preview_location) + string_slot('ReturnLocation', RETURN_ADDRESS)
  @second = @correspondent.request { |xml| with_slots(xml, slots) }

  @correspondent.submit(@second, exchange_id: @exchange_id)
end

Quand('le requêteur étranger envoie en {string} la seconde requête avec l\'adresse de l\'espace') do |version|
  slots = string_slot('PreviewLocation', issued_error.preview_location)
  @second = @correspondent.request(specification: EdmSpecification.find(version)) { |xml| with_slots(xml, slots) }

  @correspondent.submit_on_the_earlier_line(@second)
end

def second_answer
  journalled('la France ait répondu la seconde requête', event_type: 'response_sent', request_id: @second.request_id)
end

Alors('la France envoie le document que l\'usager a vu') do
  expect(second_answer.evidence_digest).to be_present
  expect(second_answer.evidence_digest).to eq(Digest::SHA256.hexdigest(@seen_document)) if @seen_document
end

Alors('la France envoie une réponse sans justificatif') do
  expect(second_answer).to have_attributes(evidence_digest: nil)
  expect(second_answer.regrep_body).to include('<rim:RegistryObjectList/>')
end

Alors('la page de l\'espace affiche le lien de retour vers la démarche') do
  patiente_jusqu_a('la page offre le lien de retour') do
    space_browser.follow_address(issued_error.preview_location)
    space_browser.links('a.fr-btn').include?(RETURN_ADDRESS)
  end
end

Alors('la page affiche que le choix est enregistré, sans rien proposer de choisir') do
  expect(space_browser.title).to eq(I18n.t('preview_sessions.show.recorded.title'))
  expect(space_browser.body).not_to include('type="radio"')
end
