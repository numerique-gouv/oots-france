module EvidenceProvision
  # Records what went out, and closes the exchange on it.
  class JournalAnswer < ApplicationInteractor
    include Answered

    def call
      answer = context.answer

      answer.record(audit_trail, **answered(context.answer_message_id))
      settle(answer)
    end

    private

    # The exchange France opened on receiving the request reaches its end here
    # once an answer has gone out: answering is the whole of what this side does.
    # A submission that never got through is settled by
    # `IncomingMessage::Process`, which sees the failure come back up.
    def settle(answer)
      return unknown_exchange if exchange.nil?

      answer.settle(exchange)
    end

    # `IncomingMessage::Process` opens one before dispatching, so there always
    # is one — but nothing in the code compels it, and an answer gone out with
    # its exchange unsettled would leave a pending state nothing would ever
    # contradict. Said aloud, as `SettleExchange` says it.
    def unknown_exchange
      Rails.logger.warn(
        I18n.t('interactors.evidence_provision.journal_answer.unknown_exchange',
          id: context.message.exchange_id),
      )
    end

    # The row `IncomingMessage::OpenExchange` wrote on receiving this request —
    # or none, where that interactor adopted a row of the other direction, which
    # it matches on the identifier alone.
    #
    # `defined?` and not `||=`: nil is a legitimate answer here, and `||=` would
    # ask the database again every time it is read.
    def exchange
      return @exchange if defined?(@exchange)

      @exchange = Exchange.find_by(exchange_id: context.message.exchange_id, incoming: true)
    end
  end
end
