module EvidenceProvision
  # Hands the answer to the gateway.
  class SubmitAnswer < ApplicationInteractor
    include Answered

    def call
      context.answer_message_id = submit(context.answer.envelope.render)
    end

    private

    # The one departure that would otherwise vanish whole: France has built an
    # answer, the gateway has not taken it, and nothing else holds the document
    # — `Exchange` records the failure but carries no message.
    #
    # The exception is re-raised unchanged, so `IncomingMessage::Process` settles
    # the exchange either way. Only one of the two then reaches what GoodJob
    # records: that interactor re-raises a `Faraday::Error`, where an
    # `UnreadableMessageError` ends in its `give_up`, which logs and stops. This
    # row is the only durable trace of the second case, the application log
    # rotating on its own schedule.
    #
    # The envelope is rendered by `call` and not here: what this rescue means is
    # that the gateway did not take our answer, and a body that could not be
    # built in the first place is another matter.
    def submit(envelope)
      gateway.submit(envelope).message_id
    rescue Faraday::Error, UnreadableMessageError => e
      audit_trail.answer_not_sent(**answered(nil), exception: context.answer.exception, reason: e.message)
      raise
    end
  end
end
