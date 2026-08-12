# A central directory refused, or answered something unusable.
#
# Deliberately not an EbmsError: that family drives a 422 back to the French
# service provider, and a directory that is down, or whose signature does not
# check out, is not their fault. `code` carries the `EB:ERR:*` of chapter 3.2.4
# or the `DSD:ERR:*` of chapter 3.1.4 when the service supplied one, which is
# what tells a refusal apart from an outage.
class CommonServicesError < StandardError
  attr_reader :code

  def initialize(message, code: nil)
    super(message)
    @code = code
  end
end
