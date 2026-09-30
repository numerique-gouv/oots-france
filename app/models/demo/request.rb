module Demo
  # One request the demonstration procedure made, and what came back on it.
  #
  # Its own register, and never the `exchanges` table this deployment keeps: the
  # procedure is a client of the published contract like any French service
  # provider, and one reading the state of the deployment it calls would
  # demonstrate something no integrator could reproduce. What it knows of an
  # exchange is what the `202` told it.
  #
  # That register is what a delivery is placed against at all: chapter 4.10 §4.1,
  # informative, has an uncorrelatable response « logged for investigation »,
  # which presupposes a set of known ones to fail against.
  class Request < ApplicationRecord
    # `Demo::` namespaces classes of every layer, records among them, so each
    # record names its table rather than a `table_name_prefix` governing the
    # value objects too.
    self.table_name = 'demo_requests'

    # The journey and the requirement join the two identifiers: they are how the
    # zone of a card finds its own request again, the session holding nothing of
    # it, and the table has all four `null: false`.
    validates :exchange_id, :conversation_id, :journey_id, :requirement_uuid, presence: true
    validates :exchange_id, uniqueness: true
    # The member state the request was addressed to, which the card of its
    # requirement stays in for as long as the request is under way.
    validates :country_code, presence: true

    # The line the journey plays, which the click asked the contract for.
    attribute :specification, EdmSpecification::Type.new
    validates :specification, presence: true

    # Chapter 4.4 §4.3.2 gives each identifier its own job — the `ExchangeId`
    # ties together the messages of one exchange, the `ConversationId` ties them
    # to one authenticated user — so a delivery is asked for both: one naming
    # this exchange under another conversation is as unplaceable as one naming
    # no exchange at all.
    def answers?(exchange_id, conversation_id)
      self.exchange_id == exchange_id && self.conversation_id == conversation_id
    end

    def evidence? = evidence_received_at.present?

    # Chapter 4.9 §5 has the portal present a link, and the answer to the
    # confirmation is the only place that link is ever given: kept, so that the
    # departure page says the same thing at every reload, and so that nothing
    # is confirmed twice.
    def preview_link? = preview_address.present?

    def returned? = returned_at.present?

    # The departure page stands while the user has somewhere to go and has not
    # come back from it.
    def awaiting_return? = preview_link? && !returned?

    # The user back by the return address. Chapter 4.9 §5 has the portal check
    # that whoever returns is the user of the procedure, so the exchange is
    # looked up under the journey the session holds: one of any other walk is
    # ignored. The first return only: a reload of the page it lands on is the
    # same return.
    def self.return_from_preview!(journey:, exchange_id:, conversation_id:)
      returned = find_by(journey_id: journey.id, exchange_id:)
      return unless returned&.preview_link? && returned.answers?(exchange_id, conversation_id)

      returned.update!(returned_at: Time.current) unless returned.returned?
    end

    # What the screen's deadline counts from: the click, or the return from the
    # preview space, the time spent there being the user's and not the answer's.
    def waiting_since = returned_at || created_at

    # Chapter 1 §4.2 has the user unable to « modify its content in any way », so
    # what is filed is what arrived, byte for byte, and the digest is taken of
    # those same bytes rather than recomputed anywhere else.
    def receive_evidence!(content)
      update!(
        evidence: content,
        evidence_digest: Digest::SHA256.hexdigest(content),
        evidence_received_at: Time.current,
      )
    end
  end
end
