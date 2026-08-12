module Oots
  # Identifiers drawn in order rather than at random, for the same reason as
  # FrozenClock: a validation report that changes on its own teaches nothing.
  #
  # They keep the shape of a UUID — the ebMS rules require one (R-EDM-ebMS-017),
  # so a counter written plainly would fail validation for the wrong reason.
  class SequentialUuids
    def initialize(prefix: '1a2b3c4d-0000-4000-8000')
      @prefix = prefix
      @counter = -1
    end

    def next = format('%<prefix>s-%<counter>012d', prefix: @prefix, counter: @counter += 1)
  end
end
