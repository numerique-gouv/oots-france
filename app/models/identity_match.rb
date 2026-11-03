# The identity swap check of chapter 4.9 §2, step 18: « the identity as
# established during re-authentication matches the identity expressed using
# attributes in the evidence request ».
#
# The three attributes of the minimum data set both sides always carry, and
# the eIDAS identifier where both carry one — chapter 2.1 §2.3.1.2 letting a
# request reach the provider without it.
class IdentityMatch
  # `established`: what FranceConnect+ attested (`Demo::UserIdentity`).
  # `requested`: the subject the request names — a `NaturalPerson`, or a
  # `LegalPerson`, which no user identity establishes.
  def initialize(established, requested)
    @established = established
    @requested = requested
  end

  def match?
    requested.is_a?(NaturalPerson) && compared.all? { |attested, named| comparable(attested) == comparable(named) }
  end

  private

  attr_reader :established, :requested

  def compared
    identifiers = [established.eidas_identifier, requested.eidas_identifier]

    identifiers.all?(&:present?) ? [*minimum_data_set, identifiers] : minimum_data_set
  end

  def minimum_data_set
    [[established.family_name, requested.family_name], [established.given_name, requested.given_name],
     [established.birthdate, requested.date_of_birth]]
  end

  # FranceConnect+ and a correspondent may write « Sørensen » in two Unicode
  # forms, or in another case: neither makes it another person.
  def comparable(value) = value.to_s.unicode_normalize(:nfc).strip.downcase
end
