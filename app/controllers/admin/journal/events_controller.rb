module Admin
  module Journal
    class EventsController < BaseController
      def index
        @filter = AuditEventFilter.from(params)
        scope = AuditEvent.all

        @total = @filter.total(scope)
        @page = @filter.page_within(@total)
        # Loaded with their exchange: a link to an exchange that does not
        # exist would lead to a 404, and asking row by row would make
        # twenty-five queries. `includes` and not `joins` — an event whose
        # exchange is missing must stay visible.
        @events = @filter.apply(scope, @page).includes(:exchange).to_a
      end

      def show
        @event = AuditEvent.find(params.expect(:id))
      end
    end
  end
end
