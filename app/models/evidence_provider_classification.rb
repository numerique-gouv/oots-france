# A question the Data Service Directory asks the user, so that it can tell
# apart the several providers a country holds for one evidence type
# (chapter 3.1.4) — the town of birth, a kind of insurance.
#
# It comes back inside `DSD:ERR:0005`, and only there: `sdg:Type` says what
# shape the answer takes, `sdg:ValueExpression` where the values are published
# when it is a code list, and the descriptions carry the question itself in
# each language the provider wrote it.
#
# `sdg:SupportedValue` is deliberately not read: `R-DSD-ERR-S023` forbids it
# here, where the request the answer feeds (chapter 4.5.1) requires it. What
# the caller asks its user is therefore the `ValueExpression`, never an
# enumeration this concept carries.
#
# Validated on demand rather than on reading, like `Requirement` and for the
# same reason: a concept read only in part is still worth showing, and a
# refusal has its meaning at the moment the value is written into the reissued
# query (OOTS-52), not at the moment the answer arrives.
class EvidenceProviderClassification
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include Described

  # R-DSD-ERR-C006 makes the type mandatory and C031 fixes its three values,
  # in lower case; the inclusion below carries both.
  TYPES = %w[string boolean codelist].freeze
  CODELIST = 'codelist'.freeze

  # R-DSD-ERR-C005: a UUID (RFC 4122), that rule carrying an `i` flag where
  # the rules on the Semantic Repository identifiers do not.
  IDENTIFIER = /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/i

  # R-DSD-ERR-C033, whose own expression leaves the dots after the optional
  # midfix unescaped — read here as the literal dots of the host it spells out,
  # which is what the rule's own prose describes.
  SCHEME_ID = %r{\Ahttps://sr(\.[a-zA-Z]+)?\.oots\.tech\.ec\.europa\.eu/codelists/[A-Z]{2}/[A-Za-z0-9]{2,50}\z}

  # R-DSD-ERR-C038, which compares lower-cased.
  VALUE_EXPRESSION = %r{\Ahttps://}i

  attribute :id, :string
  attribute :scheme_id, :string
  attribute :type, :string
  attribute :value_expression, :string

  # { 'EN' => 'In which town were you born?', 'FI' => 'Missä kaupungissa…' }
  attr_reader :descriptions

  validates :id, format: { with: IDENTIFIER, message: :format }
  validates :type, inclusion: { in: TYPES }
  # R-DSD-ERR-C032 requires the scheme only of a code list, where C033 governs
  # its shape wherever the directory published one.
  validates :scheme_id, presence: true, if: :codelist?
  validates :scheme_id, format: { with: SCHEME_ID, message: :format }, allow_blank: true
  # R-DSD-ERR-C037 and C038: a code list publishes where its values are, and
  # that address is an `https://` URI — the rule comparing it lower-cased. It
  # is the whole of what the caller has to offer its user, a code list naming
  # no values leaving nothing to choose between.
  validates :value_expression, presence: true, if: :codelist?
  validates :value_expression, format: { with: VALUE_EXPRESSION, message: :format }, allow_blank: true,
    if: :codelist?
  # R-DSD-ERR-C007 and C009 make at least one description mandatory, each
  # naming its language; without one there is no question left to ask.
  validate :questions_name_their_language

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    super
  end

  def codelist? = type == CODELIST

  private

  def questions_name_their_language
    return if descriptions.any? && descriptions.keys.all?(&:present?)

    errors.add(:base, :unlabelled_question)
  end
end
