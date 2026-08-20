module Admin
  module CommonServices
    class RequirementsController < BaseController
      # Rendered whole: the published requirements fit on one page, and the
      # search field filters them in the browser.
      def index
        @requirements = catalogue.requirements
      end

      # This page is not nested under a requirement: it names one by `id`,
      # where the providers' page receives it as `requirement_id`.
      #
      # No country is named to the directory: the parameter is optional on this
      # query, and the response then carries every country's combinations at
      # once — twenty-seven at most, which the search field filters in the
      # browser.
      def show
        @requirement = found!(catalogue.requirement(params[:id]))
        @types_count = lists.sum { |list| list.evidence_types.size }
        @by_country = by_country
      end

      # What imposes it, on a page of its own: that is the other role, and the
      # requirement's own page already answers the first one end to end.
      def procedures
        @requirement = requirement
      end

      # The procedures of a single requesting country. Nothing is asked of the
      # directory again: the catalogue already carries the declarations, and it
      # is their jurisdiction that sorts them.
      def country
        @requirement = requirement
        @country = params[:country_code]
        @declared = @requirement.declared_in(@country)

        found!(@declared.presence)

        # What each procedure requires of this country, this requirement
        # included: the catalogue already carries it, a card showing only one.
        @required = @declared.filter_map(&:procedure_code).uniq.index_with do |code|
          catalogue.procedure(code).declared_requirements(@country).size
        end
      end

      private

      def lists = @lists ||= evidence_broker.evidence_type_lists(requirement_id: @requirement.id)

      def by_country = lists.group_by(&:country).sort_by { |country, _| country.to_s }
    end
  end
end
