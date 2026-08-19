module Admin
  module Journal
    class EventsController < BaseController
      def index
        @filter = AuditEventFilter.from(params)
        scope = AuditEvent.all

        @total = @filter.total(scope)
        @page = @filter.page_within(@total)
        # Chargés avec leur échange : un lien vers un échange qui n'existe pas
        # mènerait à un 404, et le demander ligne à ligne ferait vingt-cinq
        # requêtes. `includes` et non `joins` — un événement dont l'échange
        # manque doit rester visible.
        @events = @filter.apply(scope, @page).includes(:conversation).to_a
      end

      def show
        @event = AuditEvent.find(params.expect(:id))
      end
    end
  end
end
