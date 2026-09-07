# The organisation a piece of evidence is about, where the subject is not a
# natural person (chapter 4.5.1, "Legal Person slot").
#
# Personal data, and it travels in the request. The exchange log records it,
# encrypted, like the natural person it stands in for, and gives it a canonical
# key of its own form — `AuditEvent::LEGAL_SUBJECT_FIELDS`, the eIDAS
# identifier being unique where a birth an organisation does not have would be.
class LegalPerson
  include ActiveModel::Model
  include ActiveModel::Attributes
  include EidasIdentified
  include StrictValidation

  # Hard-coded: the real level should come from the eIDAS authentication of the
  # legal person, which this deployment does not yet perform. Stub, tracked as
  # OOTS-58.
  LEVEL_OF_ASSURANCE = 'High'.freeze

  attribute :eidas_identifier, :string
  attribute :legal_name, :string

  # { 'VAT' => 'FR12345678901' } — the scheme is the key, since two identifiers
  # of the same scheme do not designate one organisation.
  attr_reader :identifiers

  validates :legal_name, :eidas_identifier, presence: true
  validate :identifiers_name_a_published_scheme
  validate :identifiers_carry_a_value

  def initialize(attributes = {})
    @identifiers = attributes.delete(:identifiers) || {}
    super
  end

  # `identifiers` lives outside the attribute API for want of an `ActiveModel`
  # `Hash` type, and the exchange log writes the evidence subject from
  # `attributes`: left out, the journal would say an organisation carried no VAT
  # number where the request carried one. Empty rather than absent is the same
  # silence, so it is written as absent.
  def attributes = super.merge('identifiers' => identifiers.presence)

  private

  # R-EDM-REQ-C055 compares the `schemeID` to `IdentifierSchemes` exactly, and
  # refuses as fatal anything else — the French SIRET included, which
  # identifies an agent of the exchange and never the subject of an evidence.
  def identifiers_name_a_published_scheme
    unpublished = identifiers.keys - IdentifierScheme::LEGAL_PERSON
    return if unpublished.empty?

    errors.add(:base, :unpublished_identifier_scheme, schemes: unpublished.join(', '))
  end

  # A blank value renders as an empty element, which asserts an identifier that
  # was never established — the reason `_natural_person.xml.erb` writes its own
  # optional identifier only when there is one.
  def identifiers_carry_a_value
    blank = identifiers.select { |_scheme, value| value.blank? }.keys
    return if blank.empty?

    errors.add(:base, :valueless_identifier, schemes: blank.join(', '))
  end
end
