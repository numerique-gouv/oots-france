# The address of an agent.
#
# The TDD require an address on agents classified `ER`, `EP` and `ERRP`
# (R-EDM-REQ-C073 and its response and error counterparts), and require only
# the country within it. Country-only is therefore a valid address, not a
# truncated one, and it is all the requester directory carries.
#
# The postal lines come from the Data Service Directory, which publishes them
# for a foreign provider. No outgoing message renders them; the operator
# console does.
class Address
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  attribute :country, :string, default: 'FR'
  attribute :thoroughfare, :string
  attribute :post_code, :string
  attribute :post_city_name, :string

  validates :country, presence: true, format: { with: /\A[A-Z]{2}\z/, message: :format }

  def postal_lines = [thoroughfare, [post_code, post_city_name].compact_blank.join(' ')].compact_blank
end
