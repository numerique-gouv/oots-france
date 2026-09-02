# Evidence types that satisfy a requirement **together**, as the Evidence
# Broker groups them (chapter 3.2.4).
#
# The grouping is the answer's meaning, not a detail of its shape: within one
# list every type is needed, and two lists answering the same requirement are
# alternatives to one another. `EvidenceTypesResponseParser` flattens them for
# the request flow, which keeps the first type it finds — choosing among the
# alternatives is chapter 4.10, and the console is where the choice can at
# least be seen.
#
# A list may also be empty on purpose: `sdg:MatchType` set to `NoMatch` is how
# a member state declares it knows no evidence of its own satisfies the
# requirement in that jurisdiction, which `EB:ERR:0001` — no information at all
# — does not say.
class EvidenceTypeList
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Described

  # The only value `R-EB-EVI-C043` allows `sdg:MatchType` to take, and the only
  # one TDD 2.0 uses; the other degrees of match the chapter describes are
  # reserved for later releases.
  NO_MATCH = 'NoMatch'.freeze

  attribute :id, :string
  attribute :country, :string
  attribute :match_type, :string

  attr_reader :descriptions, :evidence_types, :match_descriptions

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @evidence_types = attributes.delete(:evidence_types) || []
    @match_descriptions = attributes.delete(:match_descriptions) || {}
    super
  end

  # What several lists publish between them, each type counted once. Chapter
  # 3.2.4 combines the lists satisfying one requirement by `OR`, and nothing in
  # it forbids two alternatives from calling on the same evidence type: adding
  # up their sizes counts memberships, which is not what a page announcing
  # evidence types says it counts.
  #
  # By `id` and not by the object: `EvidenceType` carries no value equality, so
  # `uniq` alone would deduplicate by object identity — that is, never.
  def self.distinct_evidence_types(lists) = lists.flat_map(&:evidence_types).uniq(&:id)

  # The chapter states the equivalence in both directions: `R-EB-EVI-S015`
  # excuses an empty list only under `NoMatch`, and `NoMatch` in turn requires
  # emptiness — « In this case, EvidenceTypeList must be empty ». A declaration
  # contradicted by the types beside it is therefore not one, and the types are
  # what the page shows. Strict on the value too: a match type this release does
  # not know is not a `NoMatch`.
  def no_match? = match_type == NO_MATCH && evidence_types.empty?

  # What a page counts as published by this jurisdiction — and deliberately not
  # the negation of `no_match?`. A list left empty without declaring itself is
  # neither: `no_match?` is false for it, yet it publishes nothing. It survives
  # only beside a neighbour that carried types, which is what made the answer
  # readable at all.
  def published? = evidence_types.any?

  # Why the member state holds nothing, where it says so. Optional, and chosen
  # among the languages published by the same rule as every other wording the
  # directories publish.
  def match_description = in_preferred_language(match_descriptions)

  # `sdg:MatchDescription` is rarely French — the chapter recommends member
  # states write it in a widely understood language — so the page that shows it
  # has to say which one it is.
  def match_description_language = chosen_language_in(match_descriptions)
end
