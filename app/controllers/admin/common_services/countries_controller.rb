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

      # Ce pays en requêteur.
      def procedures
        @country = params[:country_code]
        @procedures = catalogue.procedures_in(@country)

        found!(@procedures.presence)
      end

      # Ce pays en fournisseur, l'autre moitié de son rôle. Le balayage que ça
      # demande appartient au catalogue, qui sait ce qu'un refus y vaut.
      def requirements
        @country = params[:country_code]
        @swept = catalogue.requirements
        @published = catalogue.published_in(@country)
      end

      # La même page que `procedures#country`, atteinte par l'autre bout.
      def procedure = read_declarations
    end
  end
end
