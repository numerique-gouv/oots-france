module Answers
  # An exception of chapter 4.5.3 going back to the correspondent, which the
  # exchange records under the code the correspondent will read.
  Refusal = Data.define(:envelope, :identifier, :exception) do
    include Answer

    def initialize(exception:, **)
      refuse_missing(exception, 'exception')
      super
    end

    def record(trail, **said) = trail.error_sent(**said, exception:)

    def settle(exchange) = exchange.failed!(code: exception.code, description: exception.message)
  end
end
