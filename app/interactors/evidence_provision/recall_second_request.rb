module EvidenceProvision
  # Puts back on the context the second request a preview held, as
  # `IncomingMessage::Process` would have on its arrival, so the chain that
  # answered nothing then answers it now: same `@id`, same identifiers, same
  # journal.
  class RecallSecondRequest < ApplicationInteractor
    def call
      session = PreviewSession.find_by(id: context.preview_session_id)
      return unrecalled if session&.second_request.nil?

      recall(RetrievedMessageParser.new(session.second_request), session.second_message_id)
    end

    private

    # A session concluded or destroyed since the job was filed: nothing is left
    # to answer, and the log says so rather than the job ending in silence.
    def unrecalled
      Rails.logger.warn(I18n.t('interactors.evidence_provision.recall_second_request.nothing_held',
        id: context.preview_session_id))
      context.fail!
    end

    def recall(message, message_id)
      context.message = message
      context.message_id = message_id
      context.exchange = correlated(message)
    end

    def correlated(message)
      Exchange.correlate(exchange_id: message.exchange_id, request_id: readable { message.body.request_id })
    end
  end
end
