Étantdonné('un requêteur étranger qui forge ses requêtes') do
  @correspondent = FakeCorrespondent.new(requester: @requester)
end

Quand('le requêteur étranger envoie une requête sans le slot {string}') do |name|
  body = @correspondent.request { |xml| xml.sub(%r{<rim:Slot name="#{name}">.*?</rim:Slot>}m, '') }

  @exchange_id = @correspondent.submit(body)
end

Quand('le requêteur étranger envoie une requête qui déclare aussi une personne morale') do
  body = @correspondent.request do |xml|
    xml.sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) do |slot|
      "#{slot}\n<rim:Slot name=\"LegalPerson\"><rim:SlotValue/></rim:Slot>"
    end
  end

  @exchange_id = @correspondent.submit(body)
end

# Submitted twice as it stands, so the second carries the very request
# identifier the first did — the reuse chapter 4.4 makes a data service refuse.
Quand('le requêteur étranger envoie deux fois la même requête') do
  body = @correspondent.request

  @first_exchange_id = @correspondent.submit(body)
  patiente_jusqu_a('la première requête soit servie') do
    ServerAuditEvent.exists?(exchange_id: @first_exchange_id, event_type: 'response_sent')
  end

  @exchange_id = @correspondent.submit(body)
end

# The header names no exchange on that line — `R-EDM-ebMS-037` belongs to the
# 2.0.1 tag alone — so France mints one for itself and the journal is read by
# the identifier of the request.
Quand('le requêteur étranger envoie une requête en {string}') do |version|
  body = @correspondent.request(specification: EdmSpecification.find(version))

  @request_id = @correspondent.submit_on_the_earlier_line(body)
end

# The header announces one line and the body the other: chapter 4.7 §2.6.2 has
# the receiver treat that as invalid, and the refusal goes back in the version
# the header named.
Quand("le requêteur étranger envoie une requête dont l'entête dit {string} et le corps {string}") \
  do |header_version, body_version|
  body = @correspondent.request(specification: EdmSpecification.find(body_version))

  @exchange_id = @correspondent.submit(body, specification: EdmSpecification.find(header_version))
end

Alors('la France sert le justificatif dans une réponse en {string}') do |version|
  patiente_jusqu_a('la France ait répondu') do
    ServerAuditEvent.exists?(request_id: @request_id, event_type: 'response_sent')
  end

  answer = ServerAuditEvent.find_by!(request_id: @request_id, event_type: 'response_sent')

  expect(answer.evidence_digest).to be_present
  expect(answer.regrep_body).to include(version)
end

Alors('la France refuse la requête avec le code {string} et la règle {string}') do |code, rule|
  expect(refusal).to have_attributes(edm_error_code: code, detail: rule)
end

Alors('la France refuse la seconde requête avec le code {string}, au motif du chapitre 4.4') do |code|
  expect(refusal).to have_attributes(edm_error_code: code,
    detail: EvidenceProvision::ChooseAnswer::REPLAYED_IDENTIFIER)
end

Alors('la France sert la première requête') do
  expect(ServerAuditEvent.find_by!(exchange_id: @first_exchange_id, event_type: 'response_sent'))
    .to have_attributes(evidence_digest: be_present)
end

Alors('la France n\'envoie aucun justificatif') do
  expect(ServerAuditEvent.where(exchange_id: @exchange_id, event_type: 'response_sent')).to be_empty
end

# What France answered is only legible in the log: the correspondent is France
# itself over the loopback gateway, so the refusal comes back to the very
# application that issued it and no third party holds it.
def refusal
  patiente_jusqu_a('la France ait refusé') do
    ServerAuditEvent.exists?(exchange_id: @exchange_id, event_type: 'error_sent')
  end

  ServerAuditEvent.find_by!(exchange_id: @exchange_id, event_type: 'error_sent')
end
