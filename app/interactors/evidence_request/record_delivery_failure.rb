module EvidenceRequest
  # What France makes of its gateway saying that a request it submitted has not
  # reached the correspondent — an attempt refused and to be retried, or the
  # gateway giving up —, where chapter 4.4.3 knows only an answer that does not
  # come.
  #
  # An attempt refused for the configuration of the correspondent's access point
  # closes the exchange at once, as a presumption: retrying will not help until
  # someone corrects that configuration, and the user should read the failure
  # in seconds rather than after the gateway's retries. Any other refusal waits
  # for the gateway's verdict, which then closes the exchange as a fact — and
  # replaces a presumption, the sweep's included.
  class RecordDeliveryFailure < ApplicationInteractor
    def call
      exchange = submitted_exchange

      # A message France does not know, or one it sent in answer to a
      # correspondent's request, whose exchange was settled when it was
      # journalled.
      return note(:unknown) if exchange.nil?
      return note(:ignored, exchange: exchange.exchange_id) if exchange.settled? && !exchange.presumed?

      gave_up? ? exchange.undelivered!(latest_error) : weigh_refusal(exchange)
    end

    private

    # Every exchange France answers, and every one not yet submitted, carries no
    # request identifier: a notification naming none designates none of them.
    def submitted_exchange
      Exchange.find_by(request_message_id: context.message_id) if context.message_id.present?
    end

    def gave_up? = context.status == PushNotificationParser::SEND_FAILURE

    # Already presumed failed, by this rule or by the sweep: the reason keeps
    # the attempt that closed it, and the sweep's guess waits for the verdict.
    # Nothing is read, nothing is said.
    def weigh_refusal(exchange)
      return if exchange.presumed?

      error = latest_error
      exchange.refused_by_access_point!(error) if error&.configuration_refusal?
    end

    # Nil where the gateway could not say: the exchange then waits for the next
    # notification, or is closed with a reason naming no code.
    def latest_error
      gateway.message_errors(context.message_id).latest
    rescue Faraday::Error, UnreadableMessageError => e
      Rails.logger.error(I18n.t('interactors.evidence_request.record_delivery_failure.unreadable',
        id: context.message_id, error: "#{e.class}: #{e.message}"))
      nil
    end

    def note(key, **details)
      Rails.logger.warn(I18n.t("interactors.evidence_request.record_delivery_failure.#{key}",
        id: context.message_id, status: context.status, **details))
    end
  end
end
