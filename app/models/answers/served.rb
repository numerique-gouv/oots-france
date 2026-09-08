module Answers
  # The document itself, and the reference the answer made of it — chapter 4.8
  # asks the data service to log the pair, so it travels as one `Evidence`.
  Served = Data.define(:envelope, :identifier, :evidence) do
    include Answer

    def initialize(evidence:, **)
      refuse_missing(evidence, 'justificatif')
      super
    end

    def record(trail, **said) = trail.response_sent(**said, evidence:)

    def settle(exchange) = exchange.delivered!
  end
end
