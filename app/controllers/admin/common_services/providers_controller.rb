module Admin
  module CommonServices
    # The one page the Data Service Directory answers. It takes both an
    # evidence type and a country, and refuses a query missing either
    # (`DSD:ERR:0003`), so there is no listing to offer here — only a question
    # to ask.
    #
    # The country is no choice of the reader's: an evidence type is published
    # by one jurisdiction — its Semantic Repository identifier carries it,
    # `…/evidencetypeclassifications/IT/5f1faf2e…` — and asking another country
    # for it can only come back empty. The request path pairs them the same
    # way: `Directories::CommonServices` reads the types in the country asked
    # and hands that same country to the Data Service Directory.
    class ProvidersController < BaseController
      def index
        @list = found!(publishing_list)
        @evidence_type = @list.evidence_types.find { |type| type.uuid == params[:id] }
        @country = @list.country

        ask_the_directory
      end

      private

      def publishing_list
        evidence_type_lists.find { |list| list.evidence_types.any? { |type| type.uuid == params[:id] } }
      end

      def ask_the_directory
        @data_services = data_service_directory.data_services(
          evidence_type_classification: @evidence_type.id, country_code: @country,
        )
      rescue CommonServicesError => e
        # « This country holds no such evidence » is the answer this page was
        # opened to get, and it belongs beside the question. An unreachable
        # directory has no place to be shown, and goes up.
        raise if e.code.blank?

        @refusal = e
      end
    end
  end
end
