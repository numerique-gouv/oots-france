module Admin
  module CommonServices
    class RequirementsController < BaseController
      # Rendered whole: the published requirements fit on one page, and the
      # search field filters them in the browser.
      #
      # The countries each card lists are the ones that satisfy it, which the
      # catalogue can only know by sweeping itself — one directory query per
      # requirement, shared with every other page reading that sweep.
      def index
        @requirements = catalogue.requirements
        @publishing = @requirements.index_with { |requirement| catalogue.publishing_countries(requirement) }
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

      # One provider country of the page above, at an address of its own.
      # Nothing more is asked of the directory: the query names no country, so
      # the twenty-seven pages and the requirement's own share one answer.
      #
      # A country that declared `NoMatch` is not listed among those satisfying
      # the requirement, and no page therefore leads here for it — but its
      # declaration is what this page exists to show, so the address answers.
      def country
        @requirement = requirement
        @country = params[:country_code]
        @lists = found!(evidence_type_lists.select { |list| list.country == @country }.presence)
        @types_count = EvidenceTypeList.distinct_evidence_types(@lists).size
      end

      private

      def by_country = evidence_type_lists.group_by(&:country).sort_by { |country, _| country.to_s }

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
