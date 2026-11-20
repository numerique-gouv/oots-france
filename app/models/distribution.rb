# One `sdg:DistributedAs` the Data Service Directory publishes for a service:
# a format of the `OOTSMediaTypes` list, an optional language, and for a
# structured format the data model it conforms to (chapter 3.1.4 §4.3.2).
# Read for the operator console, which shows every one; a request writes only
# one — the first of the format the portal names, `DataService#requesting`, or
# else the one `DataService.requested_format` picks.
class Distribution
  include ActiveModel::Model
  include ActiveModel::Attributes

  # The two `OOTSMediaTypes` codes the `name-Structure` column marks
  # `structured`; the four others are the ones R-EDM-REQ-C107 (FATAL) forbids a
  # data model on. Written here rather than read from the code list at run
  # time: `CodeListClient` answers an outage with an empty hash, which cannot
  # decide what a fatal rule judges.
  STRUCTURED_FORMATS = %w[application/json application/xml].freeze

  # Those four others, the ones chapter 4.5.1 §3.5 calls « human-readable »,
  # which `DataService.requested_format` prefers, and publishing one of which
  # beside a structured distribution lifts C039 and C041. Taken from the code
  # list, and not from the diagnostic text of those two assertions, which also
  # names `image/jpg`: the list holds no such code, and the assertion tests
  # membership of the list, so that spelling exempts nothing — a format outside
  # the list is neither structured nor unstructured.
  UNSTRUCTURED_FORMATS = %w[application/pdf image/jpeg image/png image/svg+xml].freeze

  # Which rule requires a data model beside a structured format: R-DSD-RESP-C039
  # governs an XML distribution, C041 a JSON one — the same sentence under two
  # identifiers, and the console names, for each distribution, the one judging
  # it. The same two formats as `STRUCTURED_FORMATS` because the code list
  # marks these two `structured`, not because either list is derived from the
  # other.
  DATA_MODEL_RULES = {
    'application/xml' => 'R-DSD-RESP-C039', 'application/json' => 'R-DSD-RESP-C041',
  }.freeze

  attribute :format, :string
  attribute :language, :string
  attribute :conforms_to, :string

  def structured? = STRUCTURED_FORMATS.include?(format)

  def unstructured? = UNSTRUCTURED_FORMATS.include?(format)

  # The rule that requires a data model beside this format, nil beside the
  # others.
  def data_model_rule = DATA_MODEL_RULES[format]
end
