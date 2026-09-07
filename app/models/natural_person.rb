# The person a piece of evidence is about.
#
# Personal data: it comes out of the beneficiary token, travels in the request,
# and comes back in the response. The exchange log persists it, encrypted, for
# at least the twelve months article 17 imposes — see `AuditEvent`;
# `Exchange` deliberately keeps none of it.
class NaturalPerson
  include ActiveModel::Model
  include ActiveModel::Attributes
  include EidasIdentified
  include StrictValidation

  # `LevelsOfAssurance-CodeList`, which `R-EDM-REQ-C037` (FATAL) holds the value
  # to. Read from the beneficiary token and never defaulted: chapter 4.5.1 §3.6
  # makes the requester answerable for the level matching the authentication
  # that actually took place, and a fallback would assert one nobody performed.
  LEVELS_OF_ASSURANCE = %w[Low Substantial High].freeze

  # `Gender-CodeList` in its eIDAS profile, which the identification chapter 2.1
  # describes and which is the only one a request from here writes — not because
  # a rule holds it to that under this slot, but because `BeneficiaryToken`
  # translates what FranceConnect+ publishes, and the portal publishes these
  # three alone. What defends the profile on the way out is therefore that
  # contract, not a second validation.
  GENDERS = %w[Male Female Unspecified].freeze

  # The same list in full, its eIDAS2 profile included, which codes the values
  # as numbers — `0` to `6` and `9`, the list carrying neither `7` nor `8`.
  # What arrives is judged against this rather than against the profile above:
  # no Schematron constrains `sdg:Gender` under a `NaturalPerson` slot,
  # `R-EDM-REQ-C124` to `C126` all anchoring on `AuthorizedRepresentative`, so a
  # correspondent may write either profile there and refusing one would turn a
  # silence of the specification into a refused exchange.
  GENDER_CODES = (GENDERS + %w[0 1 2 3 4 5 6 9]).freeze

  attribute :level_of_assurance, :string
  attribute :eidas_identifier, :string
  attribute :family_name, :string
  attribute :given_name, :string
  attribute :date_of_birth, :string
  attribute :place_of_birth, :string
  attribute :gender, :string

  validates :level_of_assurance, :family_name, :given_name, :date_of_birth, presence: true
  validates :level_of_assurance,
    inclusion: { in: LEVELS_OF_ASSURANCE, admitted: LEVELS_OF_ASSURANCE.join(', ') },
    allow_blank: true
  # `allow_blank` where `EidasIdentified` carries `allow_nil`, and not by
  # oversight: no rule of `EDM-REQ-C` constrains `sdg:Gender` under a
  # `NaturalPerson` slot, so an element present and empty breaks nothing a
  # correspondent may be refused for — where an empty `sdg:Identifier` breaks
  # `R-EDM-REQ-C040`, which is FATAL. Refusing it would cost a conformant
  # exchange, and the journal keeps « present and empty » apart from « absent »
  # on purpose, `AuditEvent.subject` compacting the second alone.
  validates :gender,
    inclusion: { in: GENDER_CODES, admitted: GENDER_CODES.join(', ') },
    allow_blank: true
  # `R-EDM-REQ-C092` (FATAL) holds the free-text elements of a request to two
  # characters at least and names `sdg:PlaceOfBirth` among them. Its rule lists
  # the elements with no ancestor path, so it reaches this slot — where the
  # rules that judge the sex, anchored on `AuthorizedRepresentative`, do not.
  #
  # `allow_nil` and not `allow_blank`, where the sex takes the opposite: that
  # rule's context is the element itself, so it fires on one sent present and
  # empty exactly as on a one-character one, and only an absent element escapes
  # it. It measures `normalize-space(.)`, which is why two non-blank characters
  # are asked of the value rather than two characters of any kind — ` A` is one
  # character to the rule and would pass a length of two.
  validates :place_of_birth,
    format: { with: /\S(?:.*\S)/m, message: :too_short },
    allow_nil: true
  validates :date_of_birth,
    format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: :format },
    allow_nil: true
end
