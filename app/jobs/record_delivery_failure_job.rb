# Handles one notification that a request France submitted has not reached its
# recipient, in its own process: reading the cause is a call to the gateway,
# and the gateway is entitled to a prompt acknowledgement of its notification.
#
# No `retry_on`: the call to the gateway that may fail is already absorbed by
# `EvidenceRequest::RecordDeliveryFailure`, and a `WAITING_FOR_RETRY` is
# notified again at the next attempt.
class RecordDeliveryFailureJob < ApplicationJob
  queue_as :default

  def perform(message_id, status)
    EvidenceRequest::RecordDeliveryFailure.call(message_id:, status:)
  end
end
