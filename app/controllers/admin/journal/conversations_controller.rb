module Admin
  module Journal
    # A conversation has no record of its own: chapter 4.4 makes it an
    # identifier that several exchanges share, not a thing this application
    # opens. The page is therefore built from the exchanges that name it, each
    # with the events it left — the reading chapter 4.7 gives the identifier
    # for, and the only one that answers « what did this user's session do ? ».
    class ConversationsController < BaseController
      def show
        @conversation_id = params.expect(:id)

        # Through the association `Exchange` already declares, eager-loaded:
        # what an exchange's journal is belongs there, and the page of one
        # exchange reads it the same way.
        @exchanges = Exchange.where(conversation_id: @conversation_id)
          .order(:created_at).includes(:audit_events)

        # A conversation nothing names is a conversation that never happened:
        # answered like an exchange nobody opened, rather than as an empty page
        # that would read as one with no events.
        raise ActiveRecord::RecordNotFound if @exchanges.empty?
      end
    end
  end
end
