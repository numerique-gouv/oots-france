module Answers
  # Chapter 4.9 §2, step 9: the `EDM:ERR:0002` sending the user to France's
  # preview space. Not a failure: the exchange waits for its second request.
  PreviewRequired = Data.define(:envelope, :identifier, :location) do
    include Answer

    def initialize(location:, **)
      refuse_missing(location, 'adresse de prévisualisation')
      super
    end

    def exception = EdmException::AUTHORIZATION

    def record(trail, **said) = trail.error_sent(**said, exception:, preview_location: location)

    def settle(exchange) = exchange.preview_required!(location)
  end
end
