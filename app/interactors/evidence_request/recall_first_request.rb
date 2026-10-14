module EvidenceRequest
  # Puts back on the context what the first request of a preview was built
  # from, so that `SendToGateway` builds the second from the same — chapter 4.9
  # §2 step 12: « For all rim:Slots except IssueDateTime, this evidence request
  # have the same content as the first request ». The subject is not among it:
  # `DecryptBeneficiary` has just read it from the token the portal gave again;
  # nor are the user's answers to the questions of the Data Service Directory,
  # which the portal gives again too.
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
        preview_possible: basis.preview_possible, provider_classifications: answered(basis.provider_classifications),
      }
    end

    def answered(classifications)
      given = EvidenceProviderClassification.answers_for(classifications, context.provider_classification_answers)

      classifications.map { |classification| classification.answered(given[classification.id]) }
    end
  end
end
