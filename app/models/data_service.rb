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

  # R-DSD-RESP-C010, which governs what the directory may publish, and not the
  # looser R-EDM-REQ-C034, which also tolerates the `distributions/` prefix of
  # the v1.0: this value is read from a directory answer, and what this pattern
  # lets through satisfies C034 by construction. Both rules accept an
  # environment midfix — `sr.acc.` on the acceptance instance.
  DATA_MODEL = %r{\Ahttps://sr(\.[a-zA-Z]+)?\.oots\.tech\.ec\.europa\.eu/datamodels/\S+\z}

  # The two `OOTSMediaTypes` codes the `name-Structure` column marks
  # `structured`; the four others are the ones R-EDM-REQ-C107 (FATAL) forbids a
  # data model on. Written here rather than read from the code list at run
  # time: `CodeListClient` answers an outage with an empty hash, which cannot
  # decide what a fatal rule judges.
  STRUCTURED_FORMATS = %w[application/json application/xml].freeze

  attribute :id, :string
  attribute :evidence_type_classification, :string
  attribute :distribution_format, :string
  attribute :distribution_language, :string
  attribute :distribution_conforms_to, :string
  # R-DSD-RESP-S027 (FATAL) makes `sdg:DistributedAs` mandatory, so a directory
  # publishing none departs from the specification — which the three attributes
  # above cannot say, being nil alike for an element absent and one published
  # empty. Only a directory answer can turn it false; everything else builds a
  # service around a distribution it already holds.
  attribute :distribution_published, :boolean, default: true
  attribute :level_of_assurance, :string

  attr_reader :descriptions, :details, :providers

  validates :id, format: { with: IDENTIFIER }
  validates :evidence_type_classification, format: { with: CLASSIFICATION }
  # R-EDM-REQ-C032 makes `DistributedAs` mandatory, and a distribution without
  # its format says nothing.
  validates :distribution_format, presence: true
  validates :distribution_language, format: { with: LANGUAGE }, allow_blank: true
  # Optional here whatever the format. R-DSD-RESP-C067 forbids it outright on
  # an unstructured one; C039 and C041 make it mandatory on an XML — resp. a
  # JSON — distribution only when the directory publishes no unstructured
  # sibling for the same evidence type, which a lone distribution cannot
  # settle.
  validates :distribution_conforms_to, format: { with: DATA_MODEL }, allow_blank: true
  # R-EDM-REQ-C029 and C031, the counterparts of C010 and C094 on this slot:
  # `lang` is mandatory on `sdg:Title` and `sdg:Description` alike.
  validate :wordings_name_their_language

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @providers = attributes.delete(:providers) || []
    super
  end

  # Which of the two families of R-EDM-REQ-C107 the requested format falls in,
  # and so whether a data model may be written beside it. Unknown formats count
  # as unstructured, the rule being fatal in that direction alone.
  def structured_distribution? = STRUCTURED_FORMATS.include?(distribution_format)

  private

  def wordings_name_their_language
    return if descriptions.keys.all?(&:present?) && details.keys.all?(&:present?)

    errors.add(:base, :unlabelled_wording)
  end
end
