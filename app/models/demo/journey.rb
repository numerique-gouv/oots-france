module Demo
  # One walk through the demonstration procedure, from the authentication that
  # opened it to the identification that replaces it.
  #
  # Chapter 4.4 §4.3.2 puts the boundary in the portal's hands — « The Procedure
  # Portal defines session boundaries and determines which actions belong to the
  # same user journey and ConversationId » — and lets the portal name the
  # conversation rather than await one: chapter 4.7 §2.5.1 has « The initial
  # ConversationId for a conversation MAY be assigned by the Online Procedure
  # Portal or its Intermediary Platform », the thing named being a conversation
  # and not a message. So it is named here, the instant the authentication
  # yields an identity, and no click has to find out whether a neighbour has
  # named one first.
  #
  # This is all the session keeps of what the procedure has asked for: a click
  # writes nothing here, it writes a row of `demo_requests` naming this journey.
  # Two clicks made in the same instant therefore each file their own row, and
  # neither can lose the other.
  #
  # Frozen by both factories, which makes « a click writes nothing here » a
  # property of the type rather than of its callers: an instance is written
  # once, when the authentication opens it, and read for the rest of the
  # session.
  #
  # The identifier and the conversation are two things. Identifying anew drops
  # what the previous journey asked for, whoever comes back; the conversation
  # survives, chapter 4.4 §4.3.2 forbidding its reuse only « if the user
  # authenticates with a different identity ».
  class Journey
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :id, :string
    attribute :conversation_id, :string
    # The pseudonym FranceConnect+ hands this service provider, which is what
    # tells one identity from another. Personal data, like the identity beside
    # it in the session, and persisted no further than the encrypted cookie.
    attribute :subject, :string

    validates :id, :conversation_id, :subject, presence: true

    # The journey an identification opens. `previous` is the one it replaces,
    # `nil` on a first sign-in; its conversation is carried over when the same
    # user comes back, and a new one is minted otherwise.
    #
    # `R-EDM-ebMS-017` (FATAL) — « The eb:ConversationId MUST be expressed as
    # UUID » — which is what `UuidGenerator` mints, injected by keyword like the
    # builders take it so a spec can freeze both identifiers.
    def self.opened(previous:, subject:, uuid: UuidGenerator.new)
      new(id: uuid.next, conversation_id: conversation_for(previous, subject) || uuid.next, subject:).freeze
    end

    def self.conversation_for(previous, subject)
      return nil if previous.nil? || previous.subject != subject

      previous.conversation_id
    end
    private_class_method :conversation_for

    # The session cookie holds a plain hash and gives back string keys — and it
    # outlives the shape this class had when it was written, as
    # `Demo::UserIdentity` says of its own. A session this class can no longer
    # read is no session, and the pages that rest on it send the user back to
    # identify themself.
    def self.from_session(stored)
      stored.nil? ? nil : new(stored.symbolize_keys).freeze
    rescue ActiveModel::UnknownAttributeError
      nil
    end

    def to_session = attributes.compact
  end
end
