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

  # `Gender-CodeList` in its eIDAS profile. The eIDAS2 profile of the same list
  # codes them as numbers — `0` to `6` and `9`, the list carrying neither `7`
  # nor `8` — and this application follows the eIDAS one —
  # the identification chapter 2.1 describes. Refused here rather than by a
  # rule: no Schematron constrains `sdg:Gender` under a `NaturalPerson` slot,
  # `R-EDM-REQ-C124` to `C126` all anchoring on `AuthorizedRepresentative`.
  GENDERS = %w[Male Female Unspecified].freeze

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
  validates :gender, inclusion: { in: GENDERS, admitted: GENDERS.join(', ') }, allow_blank: true
  validates :date_of_birth,
    format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: :format },
    allow_nil: true
end
