# The identifier schemes of an OOTS exchange, in the four unrelated senses the
# TDD give that word: the two this deployment declares itself under, the list
# an evidence *subject* may name (`LEGAL_PERSON`), the form any agent's
# identifier must take, whoever emits it (`agent_scheme?`), and the codelist URL
# a provider *classification* names itself by, whose country segment
# `R-EDM-REQ-C098` judges (`oots_country?`). The four share the XML attribute
# `schemeID` and nothing else — no rule of one governs another.
#
# French organisations are identified by their SIRET, which is EAS code 0009.
# Nothing need be asked of the Commission for that: the EAS list already
# carries the French registries — 0002 for SIRENE, 0009 for SIRET.
#
# The fallback exists for the intermediary platform, which has no SIRET of its
# own yet. See the "Identifier une organisation" section of
# `docs/oots_context.md`.
module IdentifierScheme
  EAS_PREFIX = 'urn:cef.eu:names:identifier:EAS:'.freeze
  UNREGISTERED_PREFIX = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:'.freeze

  FRENCH = "#{EAS_PREFIX}0009".freeze
  FRENCH_FALLBACK = "#{UNREGISTERED_PREFIX}FR".freeze

  # The `IdentifierSchemes` code list published with the TDD, which R-EDM-REQ-C055
  # compares to exactly. It designates the *subject* of an evidence, where the
  # two schemes above designate a corner of the exchange: writing the SIRET into
  # an `sdg:LegalPerson` produces a message that rule refuses as fatal.
  LEGAL_PERSON = %w[VAT TAX BusinessCode LEI EORI SEED SIC].freeze

  # The `EAS` code list — Electronic Address Scheme — published with the TDD.
  EAS_CODES = %w[
    0002 0007 0009 0037 0060 0088 0096 0097 0106 0130 0135 0142 0147 0151 0154 0158 0170 0177 0183
    0184 0188 0190 0191 0192 0193 0194 0195 0196 0198 0199 0200 0201 0202 0203 0204 0205 0208 0209
    0210 0211 0212 0213 0215 0216 0217 0218 0221 0225 0230 0235 0240 0244 9910 9913 9914 9915 9918
    9919 9920 9922 9923 9924 9925 9926 9927 9928 9929 9930 9931 9932 9933 9934 9935 9936 9937 9938
    9939 9940 9941 9942 9943 9944 9945 9946 9947 9948 9949 9950 9951 9952 9953 9957 9959 AN AQ AS AU
    EM
  ].freeze

  # The `OOTS_Country-CodeList` — the countries taking part in OOTS, a far
  # shorter list than `CountryIdentificationCode`. Thirty countries and `EU`,
  # and no `oots`: `R-EDM-REQ-C098` compares the country segment of a
  # classification's `schemeID` to this list alone.
  OOTS_COUNTRIES = %w[
    AT BE BG HR CY CZ DK EE FI FR DE EL HU IS IE IT LV LI LT LU MT NL NO PL PT RO SK SI ES SE EU
  ].freeze

  # The same list plus the literal `oots`, which the rules on an agent's
  # identifier admit « for testing purposes » alongside the country codes — where
  # `C098` does not.
  UNREGISTERED_CODES = (OOTS_COUNTRIES + ['oots']).freeze

  # The head `R-EDM-REQ-C098` cuts a classification's `schemeID` at, before
  # reading the country that follows it. The rule takes the URL apart by
  # substrings and never matches its shape: `R-EDM-REQ-C097` is what governs
  # that, and refusing here what `C097` alone judges would refuse what this
  # rule admits.
  CODELIST_PREFIX = 'oots.tech.ec.europa.eu/codelists/'.freeze

  # The scheme an `sdg:Agent` may name its identifier under. The TDD assert it
  # word for word in seven places, one per agent each kind of message carries:
  # `R-EDM-REQ-C012` on the requesting agent and `C018` on the provider of a
  # request; `R-EDM-RESP-C013`, `C007` and `C039` on the requester, the provider
  # and the issuing authority of a response; `R-EDM-ERR-C010` and `C004` on the
  # requester and the error provider. One rule, read once here.
  def self.agent_scheme?(scheme)
    EAS_CODES.include?(substring_after(scheme, EAS_PREFIX)) ||
      UNREGISTERED_CODES.include?(substring_after(scheme, UNREGISTERED_PREFIX))
  end

  # XPath's `substring-after`, which the assertion uses: it finds the prefix
  # wherever it sits and yields the empty string when there is none. Anchoring
  # at the head instead would refuse `xxurn:cef.eu:names:identifier:EAS:0009`,
  # which the rule accepts — and what France accepts it echoes back into a
  # response the same assertion then judges, so accepting it stays conformant.
  def self.substring_after(value, prefix) = value.to_s.partition(prefix).last
  private_class_method :substring_after

  # XPath's `substring-before`, which `C098` applies after `substring-after`:
  # it yields the **empty string** when the separator is absent, where
  # `String#partition(…).first` yields the whole string. The difference decides
  # a case: a `schemeID` ending at `…/codelists/FR`, with no `ShortName` after
  # it, has no country segment to the rule and is refused — `partition` would
  # hand back `FR` and serve it.
  def self.substring_before(value, separator)
    head, found, = value.to_s.partition(separator)

    found.empty? ? '' : head
  end
  private_class_method :substring_before

  # The country segment of a classification's `schemeID`, read exactly as
  # `R-EDM-REQ-C098` reads it: what lies between the codelist prefix and the
  # next `/`. The environment midfix of an acceptance URL — `sr.acc.oots…` —
  # crosses `substring-after` unseen, the prefix being sought wherever it sits.
  def self.oots_country?(scheme) = OOTS_COUNTRIES.include?(codelist_country(scheme))

  # Named because the rule names it: `C098` binds this very expression to
  # `$countryCode` in a `sch:let` before comparing it, rather than comparing it
  # in place.
  def self.codelist_country(scheme) = substring_before(substring_after(scheme, CODELIST_PREFIX), '/')
  private_class_method :codelist_country
end
