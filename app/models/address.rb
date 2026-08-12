# The address of an agent, reduced to its country.
#
# The TDD require an address on agents classified `ER`, `EP` and `ERRP`
# (R-EDM-REQ-C073 and its response and error counterparts), and require the
# country within it. Nothing more is available here: the requester directory
# carries no postal address, and the DSD would be the source for a foreign
# provider's. Country-only is a valid address, not a truncated one.
class Address
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  attribute :country, :string, default: 'FR'

  validates :country, presence: true, format: { with: /\A[A-Z]{2}\z/, message: :format }
end
