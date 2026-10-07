module EvidenceRequest
  # Asks the Evidence Broker which evidence satisfies the procedure in the
  # country being asked, and keeps the requirement the request has to declare.
  #
  # The whole answer stays on the context: a procedure rests on one or more
  # requirements and every one of them is due (chapter 3.2.3). One request
  # carries one of them — chapter 4.5.1 §3.1 lets several `sdg:Requirement`
  # travel together only where a single evidence type proves them all — and
  # `requirement_id` is what says which. A caller naming none is answered the
  # first requirement the country publishes evidence for.
  #
  # Only the first type is kept. Letting the user choose among several is
  # chapter 4.10.
  #
  # `outside_procedure` resolves the requirement named by the second query of
  # the Evidence Broker alone, whether or not the broker ties it to the
  # procedure — chapter 3.2.4 §4.3 bases that query « on a requirement that is
  # known to the Procedure Portal ». The screens of the demonstration ask for
  # it; a French procedure has no reason to.
  class ResolveEvidenceType < ApplicationInteractor
    def call
      outside_procedure? ? resolve_outside_procedure : resolve
    rescue RequirementNotFound => e
      fail_with_error(:unknown_requirement, errors: [e.message])
    rescue EvidenceTypeNotFound => e
      fail_with_error(outside_procedure? ? :no_evidence_type : :unknown_procedure, errors: [e.message])
    rescue ProcedureCodeNotFound => e
      fail_with_error(:unknown_procedure, errors: [e.message])
    rescue InvalidDirectoryEntry => e
      fail_with_error(:invalid_directory_entry, errors: [e.message])
    rescue CommonServicesError => e
      fail_with_error(:common_services_refused, errors: [e.message])
    end

    private

    def resolve
      context.required_evidence = satisfying_evidence
      required = requested_evidence

      return fail_with_error(:no_evidence_type, errors: [unsatisfied]) if required.nil?

      keep(required)
    end

    # No fallback on another requirement, as below: the one named is the one
    # asked for, and a country declaring `NoMatch` for it satisfies nothing.
    def resolve_outside_procedure
      required = common_services.required_evidence_for_requirement(requirement_id, context.country_code)
      context.required_evidence = [required]

      return fail_with_error(:no_evidence_type, errors: [requirement_id]) unless required.published?

      keep(required)
    end

    def keep(required)
      context.requirement = required.requirement
      context.evidence_type = required.evidence_types.first
    end

    def outside_procedure? = context.outside_procedure.present?

    # What the caller named, or what it gets for naming nothing. A requirement
    # named but unheard of is a request nobody can fulfil under another name:
    # falling back on a neighbour would answer a question that was not asked.
    def requested_evidence
      return published_evidence if requirement_id.blank?

      named = context.required_evidence.find { |required| required.requirement.id == requirement_id }
      fail_with_error(:unknown_requirement, errors: [unknown_requirement]) if named.nil?

      named if named.published?
    end

    # The first requirement the country answered, rather than the first it
    # holds: one it declares nothing for must not stand in the way of its
    # neighbours, which are due just as much.
    def published_evidence = context.required_evidence.find(&:published?)

    def satisfying_evidence
      common_services.required_evidence_for_procedure(context.procedure_code, context.country_code)
    end

    # The requirement, where one was named: a caller told « no evidence type for
    # T1 » after naming one of its several requirements would look for the fault
    # in the procedure.
    def unsatisfied = requirement_id.presence || context.procedure_code

    # Without the country: the requirements of a procedure are read in our own
    # jurisdiction — `Directories::CommonServices#requirements` asks for
    # `Settings.common_services_country_code` — where the country being asked
    # only decides which evidence types meet them. Naming `codePays` in this
    # refusal would send the caller correcting the one parameter that cannot
    # change it.
    def unknown_requirement
      I18n.t('interactors.evidence_request.resolve_evidence_type.unknown_requirement',
        requirement: requirement_id, procedure: context.procedure_code)
    end

    def requirement_id = context.requirement_id

    def common_services = context.common_services ||= Directories::CommonServices.new
  end
end
