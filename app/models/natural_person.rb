# The person a piece of evidence is about.
#
# Personal data: it comes out of the beneficiary token, travels in the request,
# and comes back in the response. Nothing here is persisted as such — the
# retention question belongs to Conversation.
class NaturalPerson
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  # Hard-coded: the real level should come from the eIDAS authentication, which
  # this deployment does not yet perform. Stub 4 of `docs/reste_à_faire.md`.
  LEVEL_OF_ASSURANCE = 'High'.freeze

  attribute :eidas_identifier, :string
  attribute :family_name, :string
  attribute :given_name, :string
  attribute :date_of_birth, :string

  validates :family_name, :given_name, :date_of_birth, presence: true
  validates :date_of_birth,
    format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: :format },
    allow_nil: true
end
