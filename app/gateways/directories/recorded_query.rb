module Directories
  # Answers as `CommonServicesQuery` does, from a copy of the directories and
  # never from them. A question the copy holds no answer to raises
  # `ActiveRecord::RecordNotFound`.
  class RecordedQuery
    def initialize(snapshot)
      @snapshot = snapshot
    end

    def search(parameters, parser:) = parser.new(@snapshot.answer(DirectorySnapshot::Answer.key(parameters)))
  end
end
