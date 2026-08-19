module EvidenceRequest
  # Asks the Evidence Broker which evidence satisfies the procedure in the
  # country being asked, and keeps the requirement the request has to declare.
  #
  # Only the first type is kept. Letting the user choose among several is
  # chapter 4.10.
  class ResolveEvidenceType < ApplicationInteractor
    def call
      resolve
    rescue ProcedureCodeNotFound, EvidenceTypeNotFound => e
      fail_with_error(:unknown_procedure, errors: [e.message])
    rescue InvalidDirectoryEntry => e
      fail_with_error(:invalid_directory_entry, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def resolve
      required = satisfying_evidence
      evidence_type = required.evidence_types.first

      return fail_with_error(:no_evidence_type, errors: [context.procedure_code]) if evidence_type.nil?

      context.requirement = required.requirement
      context.evidence_type = evidence_type
    end

    def satisfying_evidence
      context.common_services.evidence_types_for_procedure(context.procedure_code, context.country_code)
    end
  end
end
