# One error recorded on an attempt of the gateway to hand a message France
# submitted to the correspondent's access point — the gateway's own, or the one
# the access point signalled —, as `getMessageErrors` of the Domibus WS plugin
# reports it: the ebMS code, the detail, and when it was recorded.
#
# The plugin writes the code as the name of its enumeration, `EBMS_0003`, where
# ebMS 3.0 Core §6.7 writes `EBMS:0003`. Both are read, and the norm's form is
# the one kept: it is what an operator searches for.
class DeliveryError < Data.define(:code, :detail, :timestamp)
  # ebMS 3.0 Core §6.7.1 and §6.7.2: the four codes by which an access point
  # refuses a message for its own configuration — a party it does not know, a
  # process it does not match, a signature it does not accept. Retrying changes
  # nothing until someone corrects that configuration, so France closes the
  # exchange at the first of them rather than waiting for the gateway to give
  # up. Every other code, `EBMS:0005` *ConnectionFailure* first among them,
  # waits for that verdict.
  CONFIGURATION_REFUSALS = %w[EBMS:0001 EBMS:0003 EBMS:0010 EBMS:0101].freeze

  def initialize(code:, detail: nil, timestamp: nil)
    super(code: code&.tr('_', ':'), detail: detail.presence, timestamp:)
  end

  def configuration_refusal? = CONFIGURATION_REFUSALS.include?(code)

  # The code and what the gateway said of it, as the reason of a failure quotes
  # them. Named rather than left to `to_s`, for the reason
  # `BusinessRuleViolation#sentence` gives.
  def summary
    return code if detail.nil?

    I18n.t('models.delivery_error.summary', code:, detail:)
  end
end
