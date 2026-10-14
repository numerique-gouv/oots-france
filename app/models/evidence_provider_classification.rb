# A question the Data Service Directory asks of the user to tell apart the
# providers of one evidence type in one country, and, once answered, what a
# request carries of it (chapter 3.1.4 §4.4.3.3, chapter 4.5.1 §3.4).
class EvidenceProviderClassification
  # `R-EDM-REQ-C019`: a bare UUID, with neither the `urn:uuid:` prefix
  # `R-EDM-REQ-S004` puts on the request's own identifier nor any constraint on
  # the version nibble and the variant one. Case-insensitive, its assertion
  # carrying the `i` flag where `C008`'s does not.
  IDENTIFIER = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # `R-EDM-REQ-C095`, compared as its assertion compares — raw, with neither
  # `normalize-space` nor an `i` flag, so ` codelist ` and `Codelist` are
  # refused.
  TYPES = %w[string boolean codelist].freeze

  # The type whose three extra rules `require_code_list_expression` reads, and
  # the one the example published with chapter 4.5.1 carries.
  CODE_LIST = 'codelist'.freeze

  # The types `R-EDM-REQ-C103` holds to a `sdg:StringValue`, where `C104` holds
  # `boolean` to a `sdg:BooleanValue`.
  STRING_TYPES = %w[codelist string].freeze
end
