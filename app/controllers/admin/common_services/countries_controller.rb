module Admin
  module CommonServices
    # The catalogue read by jurisdiction, where `procedures` reads it by code.
    # Both list the same declarations; which of the two a reader wants depends
    # on whether they came with a country in mind or a procedure.
    class CountriesController < BaseController
      def index
        @procedures = catalogue.countries
          .index_with { |code| catalogue.procedures_in(code) }
          .sort_by { |code, _| named_or_code(code) }
      end

      # This country as a requester.
      def procedures
        @country = params[:country_code]
        @procedures = catalogue.procedures_in(@country)

        found!(@procedures.presence)
      end

      # This country as a provider, the other half of its role. The sweep that
      # takes belongs to the catalogue, which knows what a refusal is worth.
      def requirements
        @country = params[:country_code]
        @swept = catalogue.requirements
        @published = catalogue.published_in(@country)
      end

      # The same page as `procedures#country`, reached from the other end.
      def procedure = read_declarations
    end
  end
end
