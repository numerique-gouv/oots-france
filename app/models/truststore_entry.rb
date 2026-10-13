# One certificate of the truststore the gateway has loaded, as
# `GET /ext/truststore/entries` lists it: the alias it is stored under — the
# name of a party of the PMode — and its subject.
class TruststoreEntry < Data.define(:name, :subject)
  # Chapter 4.7 §4.3 has the subject of an access point's certificate carry
  # `countryName`, an ISO 3166 code; the country list of the TDD writes Greece
  # `EL` where ISO 3166 writes `GR`.
  ISO_TO_COUNTRY_LIST = { 'GR' => 'EL' }.freeze

  # One `type=value` of a distinguished name, as RFC 2253 separates them by `,`
  # or `+`: a separator escaped by a backslash or quoted belongs to its value,
  # so that a `C=` written inside another attribute is not taken for the country.
  ATTRIBUTE = /(?:\\.|"(?:\\.|[^"\\])*"|[^,+"\\])+/

  # The country of the subject, in the codes of the country list.
  def country_code
    code = attributes.find { |type, _| type.casecmp?('C') }&.last
    ISO_TO_COUNTRY_LIST.fetch(code, code)
  end

  private

  # Read by hand rather than by `OpenSSL::X509::Name.parse_rfc2253`, which
  # refuses the keywords Java writes the subject with — `EMAILADDRESS`,
  # `SERIALNUMBER` — and any multi-valued RDN.
  def attributes = subject.to_s.scan(ATTRIBUTE).map { |attribute| attribute.split('=', 2).map(&:strip) }
end
