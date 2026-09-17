# What the detail page of a journalled event shows: its columns, in order, each
# with the wording it carries and the reading its value asks for.
#
# The order lives here and not in `config/locales/fr.yml`. A wording is
# rewritten and a key is renamed — neither is a change to what the page shows,
# and one of them used to move a column or call a method the record does not
# have.
class AuditEventPresenter
  # Every column that carries something, decrypted subject included: this is the
  # page one comes to in order to know, and withholding a field here would send
  # the reader to a console to read it. The type alone is left out, the badge
  # above the table saying it, as an exchange's own page does with its status.
  COLUMNS = %i[occurred_at ebms_action conversation_id exchange_id message_id request_id response_id
               requesting_authority_id requesting_authority_scheme
               providing_authority_id providing_authority_scheme
               evidence_requester_id procedure_code country_code evidence_type_id
               evidence_subject evidence_subject_key
               evidence_identifier evidence_digest evidence_mime_type evidence_content_id
               regrep_mime_type edm_error_code preview_location detail regrep_body].freeze

  # How a cell is read, where reading it as text would say less: a date, an
  # identifier that leads somewhere, a document. Columns absent from here are
  # read as the identifiers they are.
  READINGS = { occurred_at: :timestamp, conversation_id: :conversation, exchange_id: :exchange,
               procedure_code: :procedure, country_code: :country, evidence_type_id: :address,
               preview_location: :address, edm_error_code: :edm_error_code,
               evidence_subject: :subject, regrep_body: :regrep_body }.freeze
  PLAIN = :identifier

  # The two readings that are flow content — a folded document and a definition
  # list. `DecryptedValueComponent` wraps an encrypted cell in a `<span>` unless
  # told otherwise, and a `<span>` cannot take either.
  FLOW = %i[subject regrep_body].freeze

  Row = Data.define(:name, :label, :value, :reading, :encrypted) do
    def encrypted? = encrypted

    def flow? = FLOW.include?(reading)
  end

  def initialize(event)
    @event = event
  end

  def rows = COLUMNS.filter_map { |name| row(name) }

  private

  attr_reader :event

  def row(name)
    value = event.public_send(name)
    # Emptiness tested without `blank?`, which matches a regexp and so raises on
    # the RegRep body when a correspondent sent bytes that are not valid UTF-8 —
    # bytes the journal keeps whole.
    return if value.to_s.empty?

    reading = READINGS.fetch(name, PLAIN)

    Row.new(name:, label: I18n.t("admin.journal.attributes.#{name}"), value: read(reading, value),
      reading:, encrypted: AuditEvent.encrypted_attributes.include?(name))
  end

  # Parsed rather than shown as the JSON string the column holds: chapter 4.5.1
  # describes a subject with repeated and structured attributes, which one line
  # of JSON would never make readable — and the encoder writes an ampersand as
  # `\u0026`, which only a parse undoes.
  def read(reading, value) = reading == :subject ? event.described_subject : value
end
