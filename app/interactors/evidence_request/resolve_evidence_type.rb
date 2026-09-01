module EvidenceRequest
  # Asks the Evidence Broker which evidence satisfies the procedure in the
  # country being asked, and keeps the requirement the request has to declare.
  #
  # The whole answer stays on the context: a procedure rests on one or more
  # requirements and every one of them is due (chapter 3.2.3). How many requests
  # that turns into, and in what shape, is OOTS-139 — until then one exchange
  # leaves, carrying one of them.
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
      context.required_evidence = satisfying_evidence
      required = published_evidence

      return fail_with_error(:no_evidence_type, errors: [context.procedure_code]) if required.nil?

      context.requirement = required.requirement
      context.evidence_type = required.evidence_types.first
    end

    # The first requirement the country answered, rather than the first it
    # holds: one it declares nothing for must not stand in the way of its
    # neighbours, which are due just as much.
    def published_evidence = context.required_evidence.find(&:published?)

    def satisfying_evidence
      context.common_services.required_evidence_for_procedure(context.procedure_code, context.country_code)
    end
  end
end
