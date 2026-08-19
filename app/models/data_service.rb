# What the Data Service Directory publishes for one evidence type in one
# country (chapter 3.1.4): the organisations able to deliver it, and the
# identifier the directory itself assigns to the pairing.
#
# Chapter 4.5.1 has the `DataServiceEvidenceType` slot of a request « adopted
# from the QueryResponse of the Data Services Directory », so this is what an
# outgoing request writes there — title, description and distribution included.
# The level of assurance is not: the same chapter has a request omit it, and
# only the console reads it here. Validated on demand rather
# than on reading, like `Requirement`: the console lists what the directory
# publishes, a message may not carry all of it.
class DataService
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include Described

  # R-EDM-REQ-C026: the identifier the directory assigns to the pairing is a
  # bare UUID, where the classification below is a Semantic Repository URL. `\h`
  # rather than `[a-f0-9]` because this rule alone carries the `i` flag.
  IDENTIFIER = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  # R-EDM-REQ-C027. Its country segment is either an upper-case code of the
  # `OOTS_Country-CodeList`, or the lower-case `oots` the rule allows « for
  # testing purposes and agreed OOTS data models » — the case matters, that
  # rule carrying no `i` flag. Membership of the code list is not checked here:
  # the list is published by the Commission and fetched at run time
  # (`CodeListClient::COUNTRIES`), and the Schematron judges the message.
  CLASSIFICATION = %r{\Ahttps://sr(\.[a-zA-Z]+)?\.oots\.tech\.ec\.europa\.eu/evidencetypeclassifications/
                      (oots|[A-Z]{2})/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z}x

  # R-EDM-REQ-C118: a code of the `LanguageCode` list, all of which are two
  # upper-case letters. Optional, chapter 4.5.1 defining its absence.
  LANGUAGE = /\A[A-Z]{2}\z/

  attribute :id, :string
  attribute :evidence_type_classification, :string
  attribute :distribution_format, :string
  attribute :distribution_language, :string
  attribute :level_of_assurance, :string

  attr_reader :descriptions, :details, :providers

  validates :id, format: { with: IDENTIFIER }
  validates :evidence_type_classification, format: { with: CLASSIFICATION }
  # R-EDM-REQ-C032 makes `DistributedAs` mandatory, and a distribution without
  # its format says nothing.
  validates :distribution_format, presence: true
  validates :distribution_language, format: { with: LANGUAGE }, allow_blank: true
  # R-EDM-REQ-C029 and C031, the counterparts of C010 and C094 on this slot:
  # `lang` is mandatory on `sdg:Title` and `sdg:Description` alike.
  validate :wordings_name_their_language

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @providers = attributes.delete(:providers) || []
    super
  end

  private

  def wordings_name_their_language
    return if descriptions.keys.all?(&:present?) && details.keys.all?(&:present?)

    errors.add(:base, :unlabelled_wording)
  end
end
