module Demo
  # The user of the demonstration procedure, as the authentication gave them.
  #
  # Not a `NaturalPerson`: that one is the subject a request is *about*, read
  # from a beneficiary token and written into an ebMS message. This one is what
  # an authentication attested — it carries the pseudonym FranceConnect+ hands
  # each service provider, the ID Token that ends the session, and where the
  # identity came from, none of which a request has any use for. The overlap is
  # the minimum data set, and it is held here in the vocabulary FranceConnect+
  # publishes it in; translating it is the requester's job, at the other end of
  # the beneficiary token.
  #
  # Personal data, and it is never persisted: it lives in the session alone,
  # encrypted in the cookie, and goes with it when the operator signs out.
  class UserIdentity
    include ActiveModel::Model
    include ActiveModel::Attributes
    include EidasIdentified

    # `amr` contains `eidas` for an identity of another Member State, `fc` for a
    # French pivot identity. Only the first has a button, so only the first is
    # named — chapter 2.1 §2.3.1.2 and the project carry what a French user
    # would mean here.
    EUROPEAN = 'eidas'.freeze

    attribute :given_name, :string
    attribute :family_name, :string
    attribute :birthdate, :string
    attribute :eidas_identifier, :string
    attribute :level_of_assurance, :string
    attribute :gender, :string
    attribute :place_of_birth, :string
    attribute :provenance, :string
    attribute :subject, :string
    attribute :id_token, :string

    validates :given_name, :family_name, :birthdate, :level_of_assurance, :subject, :id_token,
      presence: true
    # `R-EDM-REQ-C036` and `C037` (both FATAL): the level travels in the request
    # and belongs to `LevelsOfAssurance-CodeList`. Read from `NaturalPerson`,
    # which already holds the three codes for the other direction.
    validates :level_of_assurance,
      inclusion: { in: NaturalPerson::LEVELS_OF_ASSURANCE, admitted: NaturalPerson::LEVELS_OF_ASSURANCE.join(', ') },
      allow_blank: true
    # `YYYY-MM-DD`, the format chapter 2.1 §2.2 imposes on `sdg:DateOfBirth` and
    # the one FranceConnect+ publishes `birthdate` in.
    validates :birthdate, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: :format }, allow_blank: true
    # Held in the portal's own lower case, which is what `BeneficiaryToken`
    # translates at the other end and refuses outside of: a value the requester
    # could not carry is refused here, where the operator can still read why.
    # `birthplace` gets no such rule — it is free text, and shown as it came.
    validates :gender,
      inclusion: { in: BeneficiaryToken::GENDERS.keys, admitted: BeneficiaryToken::GENDERS.keys.join(', ') },
      allow_blank: true

    # The session cookie holds a plain hash and gives back string keys.
    def self.from_session(stored) = stored.nil? ? nil : new(stored.symbolize_keys)

    def to_session = attributes.compact

    def european? = provenance == EUROPEAN

    def identified? = eidas_identifier.present?
  end
end
