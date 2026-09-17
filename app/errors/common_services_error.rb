# A central directory refused, or answered something unusable.
#
# Deliberately not an EbmsError: that family drives a 422 back to the French
# service provider, and a directory that is down, or whose signature does not
# check out, is not their fault. `code` carries the `EB:ERR:*` of chapter 3.2.4
# or the `DSD:ERR:*` of chapter 3.1.4 when the service supplied one, which is
# what tells a refusal apart from an outage.
class CommonServicesError < StandardError
  # « Nobody publishes this here », as chapter 3.2.4 has the Evidence Broker say
  # it and chapter 3.1.4 the Data Service Directory: a directory with nothing to
  # give refuses rather than answering empty. Any other code is a directory
  # declining to answer, which settles nothing about what is published.
  NOTHING_PUBLISHED = %w[EB:ERR:0001 DSD:ERR:0001].freeze

  attr_reader :code

  def initialize(message, code: nil)
    super(message)
    @code = code
  end

  # No code at all: an invalid signature, an unresolvable NAPTR record, a
  # directory that never answered. The service did not understand the question,
  # so nothing it said is worth showing beside it.
  def outage? = code.blank?

  def nothing_published? = code.in?(NOTHING_PUBLISHED)
end
