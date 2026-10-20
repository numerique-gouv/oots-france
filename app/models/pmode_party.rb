# One party of the PMode the gateway has loaded, as `GET /ext/party` lists it:
# its name, the identifier messages address it by and that identifier's scheme,
# and the endpoint of its MSH.
class PmodeParty < Data.define(:name, :identifier, :identifier_type, :endpoint)
  # Chapter 4.7 §2.1 names a member state's access point under one of these two
  # schemes. The first ends with a country code — `R-EDM-ebMS-006` admits `oots`
  # for the Commission's own platforms, which names none; the second ends with
  # an EAS code, which names no country either.
  UNREGISTERED = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:'.freeze
  EAS = 'urn:cef.eu:names:identifier:EAS:'.freeze

  # What a message needs to address the party: its identifier and that
  # identifier's scheme.
  def addressable? = identifier.present? && identifier_type.present?

  # The country of the party, where it is one of `known`: the code its scheme
  # ends with, which is what the party declares and its messages carry; under
  # an `EAS` scheme, the `countryName` of the certificate the truststore holds
  # under its name.
  def country_code(known, certificate: nil)
    code = if identifier_type.to_s.start_with?(UNREGISTERED)
             identifier_type.delete_prefix(UNREGISTERED)
           elsif identifier_type.to_s.start_with?(EAS)
             certificate&.country_code
           end

    code if known.include?(code)
  end
end
