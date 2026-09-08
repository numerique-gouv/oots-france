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
  # country it is asserted to. Case-insensitive, as the two rules are: both
  # carry the `i` flag, so a correspondent writing `es/at/02635542Y` sends a
  # conformant identifier and refusing it would cost an exchange the
  # specification admits. `R-EDM-RESP-C028` and `C035` carry the same flag, so
  # echoing back what arrived keeps the answer conformant too.
  #
  # Anchored at both ends where the rules anchor only at the end: nothing
  # precedes `XX/YY/` in an identifier any member state asserts, and the missing
  # `^` reads as an omission rather than a licence. Membership of
  # `OOTS_Country-CodeList` is left to the rules themselves, which
  # `make schematron` plays; the floor of six characters is the Schematron's,
  # the prose saying only « up to 256 ».
  EIDAS_IDENTIFIER = %r{\A[A-Z]{2}/[A-Z]{2}/\S{6,256}\z}i

  included do
    validates :eidas_identifier, format: { with: EIDAS_IDENTIFIER, message: :format }, allow_nil: true
  end
end
