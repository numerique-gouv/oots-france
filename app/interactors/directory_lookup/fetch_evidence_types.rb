module DirectoryLookup
  # The evidence types satisfying the requirement, in the country being asked.
  class FetchEvidenceTypes < ApplicationInteractor
    include Refusing

    def call
      context.evidence_type_lists = satisfying_lists
      context.evidence_type = chosen
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
