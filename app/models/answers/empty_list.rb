module Answers
  # A successful answer carrying nothing. Chapter 4.9 §1: « If there are no
  # pieces of evidence to preview or if the user decides not to use any piece
  # of evidence, the evidence response shall contain an empty registry object
  # list » — after a preview, or at once where step 4 of §2 needs none.
  EmptyList = Data.define(:envelope, :identifier) do
    include Answer

    def record(trail, **said) = trail.response_sent(**said, evidence: nil)

    def settle(exchange) = exchange.delivered!
  end
end
