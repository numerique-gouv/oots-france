# The gateway did not give France what it asked of its REST interface: it could
# not be reached, or it refused the Plugin User. The second is a configuration
# of France to correct, not an answer of a third party to read.
class GatewayError < StandardError
  def initialize(message, refused:)
    super(message)
    @refused = refused
  end

  def refused? = @refused
end
