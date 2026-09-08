module Answers
  # Chapter 4.5.2: the evidence will exist later, and the answer says when. A
  # settled exchange and not a waiting one — the portal comes back with a new
  # Evidence Request « at the time of availability », which is another exchange.
  #
  # It carries no evidence, and says so to the log rather than leaving the
  # question open: a deferral is exactly the answer that has none.
  Deferral = Data.define(:envelope, :identifier, :available_at) do
    include Answer

    def initialize(available_at:, **)
      refuse_missing(available_at, 'date de disponibilité')
      super
    end

    def record(trail, **said) = trail.response_sent(**said, evidence: nil)

    def settle(exchange) = exchange.deferred!(available_at)
  end
end
