# The exchange the first request opened, under which France journals the
# preview: the departure of the demonstration procedure, the identifier France
# minted on the 1.2 line, or the one the correspondent sent.
def exchange_of_the_first_request
  return depart_de_la_requete.exchange_id if @demarche
  return issued_error.exchange_id if @request_id

  @exchange_id
end

# The one the second request reached: its own row on the 1.2 line, the first
# one reopened on 2.0.
def exchange_on_the_record
  exchange_id = @second ? second_answer.exchange_id : exchange_of_the_first_request
  patiente_jusqu_a('l\'échange soit réglé') do
    ServerExchange.where(exchange_id:).where.not(status: [*Exchange::IN_PROGRESS, 'preview_required']).exists?
  end

  ServerExchange.where(exchange_id:).order(:id).last
end

def event_type_named(label)
  AuditEvent::EVENT_TYPES.find { |type| I18n.t("admin.journal.event_types.#{type}") == label } ||
    raise("Aucun type de ligne ne s'affiche « #{label} »")
end

Alors('la fiche de l\'échange affiche {string}') do |status|
  badge = ApplicationController.render(ExchangeStatusComponent.new(exchange: exchange_on_the_record), layout: false)

  expect(Nokogiri::HTML.fragment(badge).text.strip).to eq(status)
end

Alors('le journal de l\'échange contient une seule ligne {string} de détail {string}') do |label, detail|
  event_type = event_type_named(label)
  lines = ServerAuditEvent.where(exchange_id: exchange_of_the_first_request, event_type:)
  patiente_jusqu_a("le journal porte la ligne « #{label} »") { lines.exists? }

  expect(lines.pluck(:detail)).to eq([detail])
end

Alors('le journal de l\'échange ne contient aucune ligne {string}') do |label|
  exchange_on_the_record

  expect(ServerAuditEvent.where(exchange_id: exchange_of_the_first_request, event_type: event_type_named(label)))
    .to be_none
end
