module EvidenceRequest
  # Puts back on the context what the first request of a preview was built
  # from, so that `SendToGateway` builds the second from the same — chapter 4.9
  # §2 step 12: « For all rim:Slots except IssueDateTime, this evidence request
  # have the same content as the first request ». The subject is not among it:
  # `DecryptBeneficiary` has just read it from the token the portal gave again.
  class RecallFirstRequest < ApplicationInteractor
    def call
      exchange = context.exchange

      recalled(exchange.request_basis).merge(procedure_code: exchange.procedure_code)
        .each { |name, value| context[name] = value }
    end

    private

    def recalled(basis)
      {
        requirement: basis.requirement, provider: basis.provider, recipient: basis.recipient,
        data_service: basis.data_service, evidence_type: basis.evidence_type,
        preview_possible: basis.preview_possible,
      }
    end
  end
end
