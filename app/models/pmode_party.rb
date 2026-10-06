# One party of the PMode the gateway has loaded, as `GET /ext/party` lists it:
# its name, the identifier messages address it by and that identifier's scheme,
# and the endpoint of its MSH.
class PmodeParty < Data.define(:name, :identifier, :identifier_type, :endpoint)
  # Chapter 4.7 names a member state's access point under this scheme, followed
  # by its country code. The Commission's own platforms use it too, with `oots`
  # in place of a country, and some member states declare an `EAS` scheme
  # instead: neither yields a country.
  UNREGISTERED = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:'.freeze

  # What a message needs to address the party: its identifier and that
  # identifier's scheme.
  def addressable? = identifier.present? && identifier_type.present?

  # The code the scheme ends with, where it is one of `known`.
  def country_code(known)
    return unless identifier_type.to_s.start_with?(UNREGISTERED)

    code = identifier_type.delete_prefix(UNREGISTERED)
    code if known.include?(code)
  end
end
