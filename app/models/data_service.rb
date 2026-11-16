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

  # The rule a service published without any `sdg:DistributedAs` departs from,
  # named here rather than in the template that shows it: a rule identifier is
  # a value the TDD fixes word for word.
  DISTRIBUTION_RULE = 'R-DSD-RESP-S027'.freeze

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

  # Every `sdg:DistributedAs` the record publishes, in its order, where the
  # attributes above read the requested one alone: what the console shows of
  # the service. Empty unless built from a directory answer.
  attr_reader :distributions

  # The classifications the service was matched on, each with the value it
  # supports, when the query carried the user's answers to a `DSD:ERR:0005`.
  attr_reader :classifications

  validates :id, format: { with: IDENTIFIER, message: :format }
  validates :evidence_type_classification, format: { with: CLASSIFICATION, message: :format }
  # R-EDM-REQ-C032 makes `DistributedAs` mandatory, and a distribution without
  # its format says nothing.
  validates :distribution_format, presence: true
  validates :distribution_language, format: { with: LANGUAGE, message: :format }, allow_blank: true
  # Optional here whatever the format, and on the request built from it too:
  # R-EDM-REQ-C070 and C071 only say SHOULD. What the directory owes is
  # stricter — R-DSD-RESP-C067 forbids the value on an unstructured
  # distribution, C039 and C041 make it mandatory on an XML — resp. a JSON —
  # one unless an unstructured one is published too, which
  # `data_model_required?` answers for the console.
  validates :distribution_conforms_to, format: { with: DATA_MODEL, message: :format }, allow_blank: true
  # R-EDM-REQ-C029 and C031, the counterparts of C010 and C094 on this slot:
  # `lang` is mandatory on `sdg:Title` and `sdg:Description` alike.
  validate :wordings_name_their_language
  validate :classifications_conform

  # The distribution France requests, among the formats the directory publishes
  # for one service. Chapter 4.5.1 §3.5 leaves the choice to the Evidence
  # Requester (« selected by the Evidence Requester during the DSD query
  # process »). The PDF is the one format France can hand the portal, so it is
  # requested wherever it stands; failing it, the first other human-readable
  # format, else the first published.
  def self.requested_format(formats)
    return EvidenceType::PDF if formats.include?(EvidenceType::PDF)

    formats.find { |format| Distribution::UNSTRUCTURED_FORMATS.include?(format) } || formats.first
  end

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @providers = attributes.delete(:providers) || []
    @classifications = attributes.delete(:classifications) || []
    @distributions = attributes.delete(:distributions) || []
    super
  end

  # What the public page of available evidence lists.
  def distribution_formats = distributions.filter_map(&:format)

  # Whether a missing data model on this distribution is the directory at
  # fault. C039 and C041 exempt a structured distribution the record also
  # publishes in an unstructured format, and nothing is then missing: the
  # console renders the two absences apart, where an empty value renders them
  # alike.
  def data_model_required?(distribution) = distribution.structured? && distributions.none?(&:unstructured?)

  # Which of the two families of R-EDM-REQ-C107 the requested format falls in,
  # and so whether a data model may be written beside it. Unknown formats count
  # as unstructured, the rule being fatal in that direction alone.
  def structured_distribution? = Distribution::STRUCTURED_FORMATS.include?(distribution_format)

  private

  def classifications_conform
    invalid = classifications.reject(&:valid?)
    return if invalid.empty?

    errors.add(:base, :invalid_classification, errors: invalid.flat_map { |found| found.errors.full_messages }.join(', '))
  end

  def wordings_name_their_language
    return if descriptions.keys.all?(&:present?) && details.keys.all?(&:present?)

    errors.add(:base, :unlabelled_wording)
  end
end
