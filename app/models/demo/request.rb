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
    # `Demo::` namespaces classes of every layer and this is the only record
    # under it, so the table is named here rather than through a
    # `table_name_prefix` governing the whole module for one row.
    self.table_name = 'demo_requests'

    validates :exchange_id, :conversation_id, presence: true
    validates :exchange_id, uniqueness: true

    # Chapter 4.4 §4.3.2 gives each identifier its own job — the `ExchangeId`
    # ties together the messages of one exchange, the `ConversationId` ties them
    # to one authenticated user — so a delivery is asked for both: one naming
    # this exchange under another conversation is as unplaceable as one naming
    # no exchange at all.
    def answers?(exchange_id, conversation_id)
      self.exchange_id == exchange_id && self.conversation_id == conversation_id
    end

    def evidence? = evidence_received_at.present?

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
