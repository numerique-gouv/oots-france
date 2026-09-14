# The document France serves for the procedures it answers with one: a PDF
# produced at the instant the response is built, saying what it attests, for
# whom and when.
#
# Stub, tracked as OOTS-82: France holds no real evidence, and this stands in
# for one. What it replaces served the same bytes to everyone, dated 1970 —
# where a demonstration is worth something only if each exchange shows its own
# document, which the journal then ties to its row by the digest of these very
# bytes.
#
# No TDD chapter governs the content of an `application/pdf`: chapter 4.7 §5
# fixes its media type and its size, chapter 4.5.1 §3.5 makes the PDF the
# human-readable form, and neither says what goes on the page. The layout, the
# wording and the order below are therefore decided here.
#
# Not an `ApplicationBuilder`: that class is the ERB machinery the XML messages
# share, and nothing of it applies to a PDF. What the two have in common is the
# one method a caller uses, `render`.
class EvidenceDocumentBuilder
  # A TrueType font, and never one of the AFM fonts prawn ships — the only ones
  # it ships, Helvetica, Times, Courier, Symbol and ZapfDingbats. Those encode
  # Windows-1252 and *raise* `Prawn::Errors::IncompatibleStringEncoding` on
  # anything outside it, so a Greek or a Polish title — which chapter 4.5.1 §3.5
  # lets a request carry, and which this document must print in the language it
  # was given in — would fail the construction of the whole response. A TrueType
  # font draws a glyph it lacks as `.notdef` and raises nothing.
  #
  # Versioned here rather than taken from the system, which a container need not
  # carry.
  FONT_PATH = 'assets/DejaVuSans.ttf'.freeze
  FONT_NAME = 'DejaVu Sans'.freeze

  FLAG_PATH = 'assets/drapeau.png'.freeze
  FLAG_WIDTH = 78

  # `#000091` and `#666666` of the DSFR, the design system the operator console
  # already renders in.
  MARINE = '000091'.freeze
  GREY = '666666'.freeze

  # What each kind of subject shows of itself, and nothing besides: the three
  # components of the canonical key `docs/journal_des_echanges.md` designates a
  # natural person by, and the name of an organisation. The response carries more
  # of both — `R-EDM-RESP-S041` admits the eIDAS identifier and the place of
  # birth beside the three, `-S042` the eIDAS identifier beside the name — and
  # none of that is printed here.
  SUBJECT_FIELDS = {
    NaturalPerson => %i[family_name given_name date_of_birth].freeze,
    LegalPerson => %i[legal_name].freeze,
  }.freeze

  def initialize(evidence_id:, instant:, evidence_type:, beneficiary:)
    @evidence_id = evidence_id
    @instant = instant
    @evidence_type = evidence_type
    @beneficiary = beneficiary
  end

  # `CreationDate` is the instant received and never `Time.now`, which is what
  # prawn would otherwise stamp: the document must be a function of its inputs,
  # failing which two builds of one response would hash differently and no spec
  # could assert anything of either. Two responses differ because their evidence
  # identifiers differ, not because the clock moved.
  #
  # Written in UTC because prawn stamps the offset of the object it is handed:
  # one moment given as a Paris `Time` and as a UTC one would otherwise produce
  # two different documents, and what the journal reads back from its own column
  # is a UTC one. `getutc` and not `utc`, which converts its receiver in place —
  # an instant this class does not own, and which raises `FrozenError` when it is
  # frozen, as a clock stopped for a test legitimately is.
  def render
    pdf = Prawn::Document.new(info: { CreationDate: instant.getutc })
    pdf.font_families.update(FONT_NAME => { normal: Rails.root.join(FONT_PATH).to_s })
    pdf.font(FONT_NAME)

    draw(pdf)
    pdf.render
  end

  private

  # Private, where a builder of XML exposes its own: the subject carries more
  # than this document may show of it — `SUBJECT_FIELDS` says what — and a
  # reader handing it back whole would undo, for anyone holding the instance,
  # exactly what the class exists to hold.
  attr_reader :evidence_id, :instant, :evidence_type, :beneficiary

  def draw(pdf)
    draw_heading(pdf)
    draw_section(pdf, I18n.t('builders.evidence_document_builder.sections.evidence_type'), evidence_type_lines)
    draw_section(pdf, I18n.t('builders.evidence_document_builder.sections.subject'), subject_lines)
    draw_identifier(pdf)
  end

  def draw_heading(pdf)
    pdf.image Rails.root.join(FLAG_PATH).to_s, width: FLAG_WIDTH
    pdf.move_down 18
    write(pdf, I18n.t('builders.evidence_document_builder.title'), size: 20, color: MARINE)
    pdf.move_down 6
    write(pdf, issued_at, size: 10, color: GREY)
  end

  def draw_section(pdf, heading, lines)
    pdf.move_down 24
    write(pdf, heading, size: 13, color: MARINE)
    pdf.move_down 4
    pdf.stroke_color GREY
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    lines.each { |line| write(pdf, line, size: 11) }
  end

  def draw_identifier(pdf)
    pdf.move_down 24
    write(pdf, I18n.t('builders.evidence_document_builder.identifier', id: evidence_id), size: 10, color: GREY)
  end

  # `inline_format` is left off — its default — and must stay off: the titles
  # and the names below come from a foreign correspondent, and prawn would read
  # a `<b>` of theirs as markup of ours.
  def write(pdf, text, size:, color: '000000')
    pdf.text(text, size:, color:, leading: 3)
  end

  def issued_at
    paris = instant.in_time_zone

    I18n.t('builders.evidence_document_builder.issued_at',
      date: paris.strftime(I18n.t('builders.evidence_document_builder.date_format')),
      time: paris.strftime(I18n.t('builders.evidence_document_builder.time_format')))
  end

  def evidence_type_lines
    [I18n.t('builders.evidence_document_builder.classification', value: evidence_type.id)] +
      evidence_type.descriptions.map do |language, title|
        I18n.t('builders.evidence_document_builder.type_title', language:, value: title)
      end
  end

  # `fetch` rather than a default, as `EvidenceSubjectBuilder` does it: a subject
  # of a type nobody listed must fail the construction rather than produce a
  # document silently saying nothing of whom it is about.
  def subject_lines
    fields = SUBJECT_FIELDS.fetch(beneficiary.class) do
      raise ConfigurationError,
        I18n.t('builders.evidence_document_builder.unknown_subject', type: beneficiary.class)
    end

    fields.map do |field|
      I18n.t("builders.evidence_document_builder.fields.#{field}", value: beneficiary.public_send(field))
    end
  end
end
