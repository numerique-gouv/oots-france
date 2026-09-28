module Answers
  # Chapter 4.9 §1: « if the user decides not to use any piece of evidence, the
  # evidence response shall contain an empty registry object list ». A
  # successful answer, carrying nothing.
  Declined = Data.define(:envelope, :identifier) do
    include Answer

    def record(trail, **said) = trail.response_sent(**said, evidence: nil)

    def settle(exchange) = exchange.delivered!
  end
end
