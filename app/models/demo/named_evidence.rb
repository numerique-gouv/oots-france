module Demo
  # What one card of the documents page named, kept for the click that follows.
  #
  # Requirement 27 of chapter 1 §2 asks for those names word for word — « The
  # user is provided with information about name of evidence provider and
  # evidence type for confirmation, before any request is made. » — so what was
  # shown is what the request carries, and `valid?` is the condition of the
  # request rather than a check on a form: a click carrying neither name was made
  # without them, and nothing may leave.
  #
  # One instance per card that can be clicked. Chapter 4.4 §4.2.2 has « different
  # basic flows … executed sequentially and/or in parallel », so a click files
  # what its own card named and never a neighbour's.
  #
  # The vocabulary is the one the request carries and `demo_requests` records:
  # `Demo::RequestEvidence::NAMED` reads each of these off its context under this
  # very name, and the register has a column per attribute. Held once here, the
  # page that writes it and the click that reads it no longer name the same thing
  # twice over.
  class NamedEvidence
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :evidence_type_name, :string
    # The language each name was published in, which the zone declares again so
    # that a screen reader does not pronounce one language as another (RGAA 8.7).
    attribute :evidence_type_language, :string
    attribute :provider_name, :string
    attribute :provider_language, :string
    # The requirement as the Evidence Broker names it, which joins the two above:
    # a row naming the document without the obligation it was asked under would
    # not say which click it answers.
    attribute :requirement_id, :string
    attribute :requirement_name, :string
    attribute :requirement_language, :string

    # The two of requirement 27, and no more: the requirement is what tells two
    # cards apart, not what the user is asked to confirm, and a directory naming
    # it in no language leaves the card standing under its evidence type.
    validates :evidence_type_name, :provider_name, presence: true

    # The session cookie holds a plain hash and gives back string keys — and it
    # outlives the shape this class had when it was written, as
    # `Demo::UserIdentity` says of its own. Both accidents land on the same
    # value: names nobody can read are no names, and an instance holding none is
    # invalid, which is the state the click already refuses to leave on.
    def self.from_session(stored)
      new(stored.to_h.symbolize_keys)
    rescue ActiveModel::UnknownAttributeError
      new
    end

    # Compacted, the session cookie being bounded at four kibibytes and a page
    # holding one entry per card: a language no directory published is worth no
    # bytes, and comes back `nil` either way.
    def to_session = attributes.compact
  end
end
