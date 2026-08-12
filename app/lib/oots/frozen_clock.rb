module Oots
  # A clock that never moves, so two runs of the specimen messages produce the
  # same bytes.
  class FrozenClock
    def initialize(instant)
      @instant = instant
    end

    def now = @instant
  end
end
