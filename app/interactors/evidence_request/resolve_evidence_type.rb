module EvidenceRequest
  # Asks the common services which evidence satisfies the procedure.
  #
  # Only the first type is kept. Letting the user choose among several is
  # chapter 4.10, and stub 1 of `docs/reste_à_faire.md` — the directory this
  # reads is a stand-in for the Evidence Broker.
  class ResolveEvidenceType < ApplicationInteractor
    def call
      types = context.common_services.evidence_types_for_procedure(context.procedure_code)
      context.evidence_type = types.first

      fail_with_error(:no_evidence_type, errors: [context.procedure_code]) if context.evidence_type.nil?
    rescue ProcedureCodeNotFound => e
      fail_with_error(:unknown_procedure, errors: [e.message])
    end
  end
end
