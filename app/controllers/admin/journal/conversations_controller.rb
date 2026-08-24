module Admin
  module Journal
    class ConversationsController < BaseController
      def index
        @filter = ConversationFilter.from(params)
        scope = Conversation.all

        @total = @filter.total(scope)
        @page = @filter.page_within(@total)
        @conversations = @filter.apply(scope, @page)
      end

      def show
        @conversation = Conversation.find_by!(conversation_id: params.expect(:id))
        @events = @conversation.audit_events.to_a
      end
    end
  end
end
