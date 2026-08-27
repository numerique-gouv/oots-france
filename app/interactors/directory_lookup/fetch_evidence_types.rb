module DirectoryLookup
  # The evidence types satisfying the requirement, in the country being asked.
  class FetchEvidenceTypes < ApplicationInteractor
    include Refusing

    # A country can answer this step with nothing and be understood: chapter
    # 3.2.4 has it declare an explicitly empty list. The chain stops there all
    # the same — the next step asks the Data Service Directory for an evidence
    # type, and there is none to name.
    def call
      context.evidence_type_lists = satisfying_lists
      context.evidence_type = chosen

      fail_with_error(:no_evidence_type, errors: [context.country_code]) if context.evidence_type.nil?
    rescue CommonServicesError => e
      refuse(e)
    end

    private

    def satisfying_lists
      context.evidence_broker.evidence_type_lists(
        requirement_id: context.requirement.id, country_code: context.country_code,
      )
    end

    def published = context.evidence_type_lists.flat_map(&:evidence_types)

    def chosen
      published.find { |found| found.uuid == context.evidence_type_id } || published.first
    end
  end
end
