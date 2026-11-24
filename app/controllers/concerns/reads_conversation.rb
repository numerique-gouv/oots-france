# A conversation has no record of its own: chapter 4.4 makes it an identifier
# that several exchanges share, not a thing this application opens. What the
# console shows of one is therefore built from the exchanges that name it, each
# with the events it left — the reading chapter 4.7 gives the identifier for,
# and the only one that answers « what did this user's session do ? ».
#
# Shared by the page of a conversation and by the export of its test files,
# which renders that page again when its form is refused.
module ReadsConversation
  extend ActiveSupport::Concern

  private

  def read_conversation(conversation_id, test_run:)
    @conversation_id = conversation_id

    @exchanges = Exchange.of_conversation(conversation_id)

    # A conversation nothing names is a conversation that never happened:
    # answered like an exchange nobody opened, rather than as an empty page that
    # would read as one with no events.
    raise ActiveRecord::RecordNotFound if @exchanges.empty?

    @test_run = test_run
    @test_files = TestFiles.new(@exchanges, test_case: test_run.test_case, run: test_run.run)
  end
end
