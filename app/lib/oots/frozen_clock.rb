module Oots
  # A clock that never moves, so two runs of the specimen messages produce the
  # same bytes. Holds a `Time`, as `Clock` does.
  class FrozenClock
    def initialize(instant)
      @instant = instant
    end

    def now = @instant
  end
end
