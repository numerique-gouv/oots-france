module DirectoryLookup
  # The evidence types satisfying the requirement, in the country being asked.
  #
  # `evidence_type_id` names one of them by UUID. A caller that offers the
  # user the alternatives — `alternatives_offered`, which only the screens of
  # the demonstration set — takes no type it was not given but the only one
  # published: requirement 26 of
  # chapter 1 §2 has the user « select and request the types of evidence », so
  # where the country publishes several and none is named, nothing is chosen
  # and the chain stops before the Data Service Directory, the lists staying on
  # the context. A single type leaves nothing to choose. Without the flag, the
  # first type published stands in for one not named, which is what the
  # console's resolution page shows.
  class FetchEvidenceTypes < ApplicationInteractor
    include Refusing

    # A country can answer this step with nothing and be understood: chapter
    # 3.2.4 has it declare an explicitly empty list. The chain stops there all
    # the same — the next step asks the Data Service Directory for an evidence
    # type, and there is none to name.
    def call
      context.evidence_type_lists = satisfying_lists
      context.evidence_type = chosen

      fail_with_error(:no_evidence_type, errors: [context.country_code]) if published.empty?
      fail_with_error(:evidence_type_unchosen, errors: [context.country_code]) if context.evidence_type.nil?
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    def satisfying_lists
      context.evidence_broker.evidence_type_lists(
        requirement_id: context.requirement.id, country_code: context.country_code,
      )
    end

    def published = @published ||= EvidenceTypeList.distinct_evidence_types(context.evidence_type_lists)

    def chosen
      named = published.find { |found| found.uuid == context.evidence_type_id }
      return named || published.first unless context.alternatives_offered

      named || (published.first if published.one?)
    end
  end
end
