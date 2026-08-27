# The identifier schemes this deployment uses to designate an organisation.
#
# French organisations are identified by their SIRET, which is EAS code 0009.
# Nothing need be asked of the Commission for that: the EAS list already
# carries the French registries — 0002 for SIRENE, 0009 for SIRET.
#
# The fallback exists for the intermediary platform, which has no SIRET of its
# own yet. See the "Identifier une organisation" section of
# `docs/oots_context.md`.
module IdentifierScheme
  FRENCH = 'urn:cef.eu:names:identifier:EAS:0009'.freeze
  FRENCH_FALLBACK = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR'.freeze

  # The `IdentifierSchemes` code list published with the TDD, which R-EDM-REQ-C055
  # compares to exactly. It designates the *subject* of an evidence, where the
  # two schemes above designate a corner of the exchange: writing the SIRET into
  # an `sdg:LegalPerson` produces a message that rule refuses as fatal.
  LEGAL_PERSON = %w[VAT TAX BusinessCode LEI EORI SEED SIC].freeze
end
