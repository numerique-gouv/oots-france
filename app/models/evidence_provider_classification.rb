# A question the Data Service Directory asks of the user to tell apart the
# providers of one evidence type in one country, and, once answered, what a
# request carries of it (chapter 3.1.4 §4.4.3.3, chapter 4.5.1 §3.4).
#
# The same record at three moments: asked in the `UserRequestedClassificationConcepts`
# slot of a `DSD:ERR:0005`, published with the value it matched in the answer
# to the query that carried the user's answer, and written into a request with
# that answer as its one `sdg:SupportedValue` — chapter 4.5.1 §3.4: « The
# remaining structure e.g. Identifier, Type, Value Expression, Description must
# be adopted from the corresponding DSD QueryResponse ».
class EvidenceProviderClassification
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Described

  # `R-EDM-REQ-C019`: a bare UUID, with neither the `urn:uuid:` prefix
  # `R-EDM-REQ-S004` puts on the request's own identifier nor any constraint on
  # the version nibble and the variant one. Case-insensitive, its assertion
  # carrying the `i` flag where `C008`'s does not.
  IDENTIFIER = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # `R-EDM-REQ-C095`, compared as its assertion compares — raw, with neither
  # `normalize-space` nor an `i` flag, so ` codelist ` and `Codelist` are
  # refused.
  TYPES = %w[string boolean codelist].freeze

  # The type whose three extra rules `require_code_list_expression` reads, and
  # the one the example published with chapter 4.5.1 carries.
  CODE_LIST = 'codelist'.freeze

  BOOLEAN = 'boolean'.freeze

  # The types `R-EDM-REQ-C103` holds to a `sdg:StringValue`, where `C104` holds
  # `boolean` to a `sdg:BooleanValue`.
  STRING_TYPES = %w[codelist string].freeze

  # `R-EDM-REQ-C101`, matched after `lower-case` as its assertion does.
  SECURE_EXPRESSION = %r{\Ahttps://}i

  attribute :id, :string
  attribute :scheme_id, :string
  attribute :type, :string
  attribute :value_expression, :string
  # The value the classification carries: the user's answer once given, or the
  # value a directory published for the service it matched. Nothing on a
  # question still unanswered.
  attribute :supported_value, :string

  # { 'EN' => 'Projectathon test case', 'EL' => 'Σενάριο Projectathon' } — the
  # question itself: « The Question that shall be raised to the user ».
  attr_reader :descriptions

  validates :id, format: { with: IDENTIFIER, message: :format }
  validates :type, inclusion: { in: TYPES, message: :inclusion }
  # `R-EDM-REQ-C096`, `C100` and `C101`, which only a `codelist` owes.
  validates :scheme_id, :value_expression, presence: true, if: :code_list?
  validates :value_expression, format: { with: SECURE_EXPRESSION, message: :format }, allow_blank: true, if: :code_list?
  # `R-EDM-REQ-C022`.
  validate :descriptions_name_their_language

  def initialize(attributes = {})
    @descriptions = (attributes.delete(:descriptions) || {}).to_h
    super
  end

  def self.from_h(stored) = new(**stored.symbolize_keys)

  # The answers given to these questions and to no others, by the identifier
  # each question carries, blank answers left out. Matched whatever the case:
  # `R-EDM-REQ-C019` reads an identifier so.
  def self.answers_for(questions, given)
    by_id = given.to_h.to_h { |id, value| [id.to_s.downcase, value.to_s.strip] }

    questions.to_h { |question| [question.id, by_id[question.id.to_s.downcase]] }.compact_blank
  end

  # Whether `given` answers every one of these questions — chapter 3.1.4
  # §4.4.3.3: « For each EvidenceProviderClassification of the DSD:ERR:0005 a
  # separate answer must be provided by the user ».
  def self.all_answered?(questions, given) = answers_for(questions, given).size == questions.size

  def code_list? = type == CODE_LIST

  def boolean? = type == BOOLEAN

  # English before French, where the rest of what a directory publishes is shown
  # French first: the demonstration speaks English, and a question is a
  # sentence the user must answer, not a name in a table cell.
  QUESTION_LANGUAGES = %w[EN FR].freeze

  def question = label(languages: QUESTION_LANGUAGES)

  def question_language = label_language(languages: QUESTION_LANGUAGES)

  # The same classification carrying the user's answer as its supported value.
  def answered(value) = self.class.new(**to_h.symbolize_keys, supported_value: value)

  # The descriptions as pairs: `jsonb` orders an object's keys its own way, and
  # the second request of a preview repeats the first one's slots « the same
  # content » (chapter 4.9 §2 step 12), in the order they were written.
  def to_h = { **attributes, 'descriptions' => descriptions.to_a }

  def ==(other) = other.is_a?(EvidenceProviderClassification) && other.to_h == to_h
  alias eql? ==

  delegate :hash, to: :to_h

  private

  def descriptions_name_their_language
    return if descriptions.keys.all?(&:present?)

    errors.add(:base, :unlabelled_wording)
  end
end
