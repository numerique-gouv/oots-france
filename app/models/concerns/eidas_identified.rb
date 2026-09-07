# The eIDAS identifier that both evidence subjects of chapter 4.5.1 carry: the
# one a Member State asserted about a person, and the one it asserted about an
# organisation.
#
# One expression for the two, because it is one shape written twice —
# `R-EDM-REQ-C040` for the natural person and `R-EDM-REQ-C051` for the legal
# one, both FATAL and both spelling out the same thing. Presence is each model's
# own: an organisation the request names is identified or it is nothing, where a
# person may reach the requester with no identifier at all, chapter 2.1 §2.3.1.2
# providing for an identity established in the requester's own country.
module EidasIdentified
  extend ActiveSupport::Concern

  # `XX/YY/Z…Z`, the two codes being the country asserting the identity and the
  # country it is asserted to. Upper case where the rules carry the `i` flag,
  # ISO 3166-1 alpha-2 codes being written that way — as `Address#country`
  # already has it. Stricter than the rule on what arrives and not on what this
  # application emits alone, the parsers validating an incoming subject against
  # this too: a correspondent writing `fr/de/…` is refused where
  # `R-EDM-REQ-C040`, case-insensitive, admits it. Membership of
  # `OOTS_Country-CodeList` is left to the rules themselves, which
  # `make schematron` plays; the floor of six characters is the Schematron's,
  # the prose saying only « up to 256 ».
  EIDAS_IDENTIFIER = %r{\A[A-Z]{2}/[A-Z]{2}/\S{6,256}\z}

  included do
    validates :eidas_identifier, format: { with: EIDAS_IDENTIFIER, message: :format }, allow_nil: true
  end
end
