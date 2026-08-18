module Admin
  module CommonServices
    class CatalogueController < BaseController
      def show
        @procedures = catalogue.procedures
        @requirements = catalogue.requirements
        @countries = catalogue.countries
      end
    end
  end
end
