class StudentStatus
  # The registry's identity in the shape `IdentityCardComponent` reads. The
  # registry yields no sex, no place of birth, no level of assurance and no
  # eIDAS identifier, and the card gives an attribute it lacks no row.
  CardIdentity = Data.define(:family_name, :given_name, :birthdate) do
    def self.from(identity)
      new(family_name: identity.family_name, given_name: identity.given_name, birthdate: identity.date_of_birth)
    end

    def gender = nil
    def place_of_birth = nil
    def level_of_assurance = nil
    def eidas_identifier = nil
  end
end
