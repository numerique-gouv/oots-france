module Admin
  module Journal
    class ConversationsController < BaseController
      include ReadsConversation

      def show
        read_conversation(params.expect(:id), test_run: TestRun.new)
      end
    end
  end
end
