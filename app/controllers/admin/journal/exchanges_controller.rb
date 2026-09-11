module Admin
  module Journal
    class ExchangesController < BaseController
      def show
        @exchange = Exchange.find_by!(exchange_id: params.expect(:id))
        # Loaded with their exchange, like the listing: every row of the journal
        # below asks whether the identifier it names was one France minted for
        # itself, and asking row by row would query once per event.
        @events = @exchange.audit_events.includes(:exchange).to_a
      end
    end
  end
end
