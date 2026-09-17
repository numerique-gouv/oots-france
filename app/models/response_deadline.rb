# The timeout of chapter 4.4.3, which both roles read and neither owns.
#
# « If a Data Service implements timeout … return a timeout exception response »
# and « If an Online Procedure Portals implements timeout, then it shall
# generate a timeout error »: two conditionals, one antecedent. A deployment may
# provide no timeout handling at all, and `Settings.timeout_enabled?` is that
# antecedent — read first everywhere, so that no duration is evaluated where
# none is configured.
#
# The two durations are not one, and are deliberately not merged: the requester
# gives up on an answer that never came, the data service refuses a request that
# arrived too late. Each side reads its own.
#
# A module and not a class, like `ProcedureCode` beside it: there is one
# deployment, and its deadline is a reading of the configuration rather than a
# thing one holds several of.
module ResponseDeadline
  def self.handled? = Settings.timeout_enabled?

  # Nothing where no timeout is handled: there is then no instant past which an
  # exchange has waited too long — which is what an absent timeout means, and
  # not what an infinite one would.
  def self.for_requester
    Settings.requester_timeout.ago if handled?
  end

  def self.for_provider
    Settings.provider_timeout.ago if handled?
  end

  # Whether a request arrived too late for the data service to owe it an answer.
  # Asked of the instant the message was sent: that side holds no `Exchange` to
  # interrogate, only the arrival itself.
  def self.passed?(sent_at)
    handled? && sent_at < for_provider
  end
end
