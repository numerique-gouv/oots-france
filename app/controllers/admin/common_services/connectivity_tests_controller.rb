module Admin
  module CommonServices
    # Asks a connectivity test towards one party of the PMode, or towards all of
    # them, and answers at once: `ConnectivityTesting::RequestTests` records the
    # tests pending and leaves their submission to a job. The one page of the
    # console that sends something to every correspondent.
    #
    # A form posted by the page's controller carries `fragment`, and gets the
    # blocks back rather than a redirection: the page does not reload.
    class ConnectivityTestsController < BaseController
      include ReadsPmodeParties

      def create
        ConnectivityTesting::RequestTests.call(parties: pmode_parties, party: params[:party])

        return render_blocks(access_point_rows) if params[:fragment].present?

        redirect_to admin_common_services_access_points_path, status: :see_other
      end
    end
  end
end
