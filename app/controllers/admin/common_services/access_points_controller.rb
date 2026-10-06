module Admin
  module CommonServices
    # The parties of the PMode the gateway has loaded, and the last connectivity
    # test France ran towards each. Read in the gateway for the parties, in the
    # local database for the tests: the page itself asks the gateway nothing else.
    #
    # With `fragment`, the blocks alone: what the page's controller asks again
    # while a test is pending.
    class AccessPointsController < BaseController
      include ReadsPmodeParties

      def index
        @rows = access_point_rows

        render_blocks(@rows) if params[:fragment].present?
      end
    end
  end
end
