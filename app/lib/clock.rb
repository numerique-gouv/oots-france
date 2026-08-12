# Injected wherever a message needs a timestamp, so a test can freeze it.
# Messages carry an ISO 8601 instant in UTC, with milliseconds.
class Clock
  def now = Time.current.utc.iso8601(3)
end
