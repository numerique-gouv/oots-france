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
        @by_country = weighed_by_country
        @types_count = @by_country.sum { |_, _, weight| weight }
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

      # Each country carries the weight its card announces, worked out once: the
      # heading is nothing but the sum of those weights, and `filter.js` recomputes
      # it from them as soon as the page loads. One value read twice, therefore,
      # rather than two expressions left to agree — which is the whole of what
      # `EvidenceTypeList.distinct_evidence_types` is asked here.
      def weighed_by_country
        by_country.map { |country, lists| [country, lists, EvidenceTypeList.distinct_evidence_types(lists).size] }
      end
    end
  end
end
