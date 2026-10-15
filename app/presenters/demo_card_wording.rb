# What the documents page of the demonstration says of one requirement of the
# procedure: what it is, the combinations of evidence types its country offers
# to satisfy it, the one chosen, and a `DemoResolutionWording` per type of that
# one — chapter 3.2.2 §2.3, « at least one Evidence for each Evidence Type
# specified in one Evidence Type List MUST be provided ».
#
# `nameable?` is what the page reads to decide whether it may offer to confirm
# at all: requirement 27 of chapter 1 §2 has the type and the provider named
# « before any request is made », and a combination is asked for whole.
class DemoCardWording
  LANGUAGES = DemoResolutionWording::LANGUAGES

  # What a card says of the combination itself, whatever its lines say.
  delegate :requirement, :requirement_language, :requirement_id, :requirement_uuid, :country_code, :failure,
    :published_nothing?, to: :head

  def initialize(lookup)
    @lookup = lookup
    @head = DemoResolutionWording.new(lookup)
  end

  # One per evidence type of the combination chosen, in the order of the list.
  def lines = @lines ||= Array(lookup.lines).map { |line| DemoResolutionWording.new(line) }

  def line(evidence_type_uuid) = lines.find { |found| found.evidence_type_uuid == evidence_type_uuid }

  # Chapter 3.2.2 §2.3: « The user can select an 'Evidence Type List' amongst
  # the ones proposed by the Evidence Broker », where there is more than one to
  # select from.
  def combinations = EvidenceTypeList.combinations(Array(lookup.evidence_type_lists))

  def choosable? = combinations.many?

  def combination = lookup.evidence_type_list

  def combination_id = combination&.id

  def nameable? = lines.any? && lines.all?(&:nameable?)

  # A combination of one type is named by that type; one of several by the
  # `sdg:Name` the Evidence Broker gives the list, in English or else in
  # French, and failing that by the titles of its types, in the order of the
  # list.
  def self.label(list)
    types = list.evidence_types
    return types.first.label(languages: LANGUAGES) if types.one?
    return list.label(languages: LANGUAGES) if named?(list)

    I18n.t('presenters.demo_card_wording.and', first: titles(types[..-2]), last: types.last.label(languages: LANGUAGES))
  end

  # The language of that name, where one language says it whole (RGAA 8.7):
  # titles joined by the English « and » are English only if every title is.
  def self.label_language(list)
    types = list.evidence_types
    return types.first.label_language(languages: LANGUAGES) if types.one?
    return list.label_language(languages: LANGUAGES) if named?(list)

    'EN' if types.all? { |type| type.label_language(languages: LANGUAGES) == 'EN' }
  end

  def self.named?(list) = LANGUAGES.intersect?(list.descriptions.keys)

  def self.titles(types)
    types.map { |type| type.label(languages: LANGUAGES) }.join(I18n.t('presenters.demo_card_wording.separator'))
  end

  private_class_method :named?, :titles

  private

  attr_reader :lookup, :head
end
