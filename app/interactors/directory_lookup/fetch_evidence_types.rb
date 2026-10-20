module DirectoryLookup
  # The evidence types satisfying the requirement, in the country being asked.
  #
  # `evidence_type_id` names one of them by UUID. Without `alternatives_offered`,
  # the first type published stands in for one not named, which is what the
  # console's resolution page shows.
  #
  # A caller that offers the user the alternatives — `alternatives_offered`,
  # which only the screens of the demonstration set — chooses a combination
  # rather than a type: chapter 3.2.2 §2.3 has the user « select an 'Evidence
  # Type List' amongst the ones proposed by the Evidence Broker », and « at
  # least one Evidence for each Evidence Type specified in one Evidence Type
  # List MUST be provided ». `evidence_type_list_id` names it; the only one
  # published needs no naming; where the country publishes several and none is
  # named, nothing is chosen and the chain stops before the Data Service
  # Directory, the lists staying on the context. `evidence_type` is then the
  # type of that combination `evidence_type_id` names, or its first.
  class FetchEvidenceTypes < ApplicationInteractor
    include Refusing

    # A country can answer this step with nothing and be understood: chapter
    # 3.2.4 has it declare an explicitly empty list. The chain stops there all
    # the same — the next step asks the Data Service Directory for an evidence
    # type, and there is none to name.
    def call
      context.evidence_type_lists = satisfying_lists
      context.evidence_type_list = chosen_combination if context.alternatives_offered
      context.evidence_type = chosen

      stop_unless_chosen
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    def stop_unless_chosen
      fail_with_error(:no_evidence_type, errors: [context.country_code]) if published.empty?
      fail_with_error(:evidence_type_unchosen, errors: [context.country_code]) if context.evidence_type.nil?
    end

    def satisfying_lists
      context.evidence_broker.evidence_type_lists(
        requirement_id: context.requirement.id, country_code: context.country_code,
      )
    end

    def published = @published ||= EvidenceTypeList.distinct_evidence_types(context.evidence_type_lists)

    def chosen
      return named_in(published) || published.first unless context.alternatives_offered

      types = context.evidence_type_list&.evidence_types.to_a
      named_in(types) || types.first
    end

    def named_in(types) = types.find { |found| found.uuid == context.evidence_type_id }

    def chosen_combination
      combinations = EvidenceTypeList.combinations(context.evidence_type_lists)

      combinations.find { |found| found.id == context.evidence_type_list_id } || (combinations.first if combinations.one?)
    end
  end
end
