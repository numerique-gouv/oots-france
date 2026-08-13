module EvidenceRequest
  # Asks the Evidence Broker which evidence satisfies the procedure in the
  # country being asked.
  #
  # Only the first type is kept. Letting the user choose among several is
  # chapter 4.10.
  class ResolveEvidenceType < ApplicationInteractor
    def call
      context.evidence_type = satisfying_types.first

      fail_with_error(:no_evidence_type, errors: [context.procedure_code]) if context.evidence_type.nil?
    rescue ProcedureCodeNotFound, EvidenceTypeNotFound => e
      fail_with_error(:unknown_procedure, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def satisfying_types
      context.common_services.evidence_types_for_procedure(context.procedure_code, context.country_code)
    end
  end
end
