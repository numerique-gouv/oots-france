module EvidenceProvision
  # Turns away a request whose requesting agent no answer could name, and writes
  # the decision to the journal, which is then the only place it can be read.
  #
  # An `EDM:ERR:0003` names the requester by copying back what the request said
  # of it — identifier, scheme, name, language of that name — so a refusal
  # founded on any of those would travel out inside a message breaking
  # `R-EDM-ERR-C010`, `C027`, `C028` or `C029`, all FATAL, under France's own
  # signature. The scheme is besides the `type` of the ebMS `finalRecipient`,
  # which is how the answer would be routed at all.
  #
  # Hence a step of its own before `ChooseAnswer`, beside
  # `RejectMalformedIdentifiers`, which turns away the ebMS identifiers for the
  # same reason and in the same shape. What a conformant answer *can* carry —
  # the country of the agent, the scheme of the beneficiary's identifier — is
  # refused by `EvidenceRequestParser#validate!` instead, and does go back.
  class RejectUnanswerableRequester < ApplicationInteractor
    def call
      request.requester
    rescue UnreadableMessageError => e
      refuse(e)
    end

    private

    def request = context.message.body

    # Hung on the exchange `IncomingMessage::OpenExchange` has already opened,
    # so the refusal joins the arrival that `IncomingMessage::Process`
    # journalled before dispatching.
    #
    # The exchange first, then what the request declares: `OpenExchange` reads
    # the requester through a `readable` that swallows exactly the failure being
    # refused here, so its two identity columns are empty for precisely these
    # requests. `declared_requester_id` and its country are read past that
    # failure, so a refusal founded on a name or on its language still records
    # who sent it — the whole of what an operator has to go on, nothing else
    # reaching them.
    def refuse(error)
      reason = said(error)
      journal(reason)

      raise UnreadableMessageError.new(reason, detail: error.detail)
    end

    # The rule travels inside the sentence rather than beside it: this reason is
    # read in one column of the journal, and a refusal that did not name what it
    # applied could not be justified afterwards.
    def said(error)
      rule = error.detail ||
             I18n.t('interactors.evidence_provision.reject_unanswerable_requester.unnamed_rule')

      I18n.t('interactors.evidence_provision.reject_unanswerable_requester.unanswerable',
        reason: error.message, rule:)
    end

    def journal(reason)
      exchange = Exchange.find_by(exchange_id: context.message.exchange_id, incoming: true)

      audit_trail.request_refused(
        requester_id: exchange&.evidence_requester_id || request.declared_requester_id,
        procedure_code: exchange&.procedure_code,
        country_code: exchange&.country_code || request.declared_requester_country,
        reason:, exchange:,
      )
    end
  end
end
