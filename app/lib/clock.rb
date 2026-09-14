# Injected wherever a message needs an instant, so a test can freeze it.
#
# A `Time` and not the string the messages carry: one reading must serve several
# renderings of one instant — the `IssueDateTime` slot of a response in UTC, and
# the evidence document it dates, in Paris time. `ApplicationBuilder#timestamp`
# holds the form the messages use.
class Clock
  def now = Time.current
end
