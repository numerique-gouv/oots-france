module Admin
  module CommonServices
    class ResolutionsController < BaseController
      def show
        @question = ResolutionFilter.from(params)

        @lookup = resolve if @question.asked?
      end

      private

      def resolve
        DirectoryLookup::Resolve.call(
          evidence_broker:, data_service_directory:,
          procedure_code: @question.procedure_code, country_code: @question.country,
          requirement_id: @question.requirement_id, evidence_type_id: @question.evidence_type_id,
        )
      end
    end
  end
end
