# The pair an ebMS message needs to designate a party: an identifier and the
# scheme it belongs to.
#
# Both must be filled in. An absent value would travel to Domibus as a property
# it accepts without complaint, and the message would then be routed nowhere —
# a failure that only shows up as silence on the other side.
class EbmsIdentity
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  attribute :id, :string
  attribute :type_id, :string

  validates :id, :type_id, presence: true

  def ==(other) = other.is_a?(EbmsIdentity) && other.id == id && other.type_id == type_id
  alias eql? ==

  def hash = [id, type_id].hash
end
