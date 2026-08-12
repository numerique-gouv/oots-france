# `Resolv` ships no NAPTR resource, and that record type is how chapter 3.4 of
# the TDD publishes the Common Services instances. Twenty lines here spare the
# application a DNS gem for one lookup.
#
# An initializer rather than `app/`: this reopens a standard library class,
# whose constant path Zeitwerk cannot infer from a file name.
#
# The shape is Resolv's, not ours — it looks resources up by a `TypeValue`
# constant it expects in exactly that case, and hands `decode_rdata` the six
# fields RFC 3403 defines.
# rubocop:disable Naming/ConstantName, Metrics/ParameterLists
class Resolv::DNS::Resource::IN::NAPTR < Resolv::DNS::Resource
  ClassValue = Resolv::DNS::Resource::IN::ClassValue
  TypeValue = 35
  ClassHash[[TypeValue, ClassValue]] = self

  attr_reader :order, :preference, :flags, :service, :regexp, :replacement

  def initialize(order, preference, flags, service, regexp, replacement)
    super()
    @order = order
    @preference = preference
    @flags = flags
    @service = service
    @regexp = regexp
    @replacement = replacement
  end

  def self.decode_rdata(message)
    order = message.get_unpack('n').first
    preference = message.get_unpack('n').first

    new(order, preference, message.get_string, message.get_string, message.get_string, message.get_name)
  end
end
# rubocop:enable Naming/ConstantName, Metrics/ParameterLists
