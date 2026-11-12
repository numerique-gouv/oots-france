module Directories
  # Answers as `CommonServicesQuery` does, and keeps every body it read under
  # the key `RecordedQuery` will look it up by.
  #
  # Kept before it is parsed: the refusals the public page states — a
  # `DSD:ERR:0001`, `0002` or `0005` — arrive as signed answers, and the page
  # replays them through the same parser.
  class RecordingQuery
    def initialize(query, into:)
      @query = query
      @answers = into
    end

    def search(parameters, parser:)
      body = @query.read(parameters)
      @answers[DirectorySnapshot::Answer.key(parameters)] = body

      parser.new(body)
    end
  end
end
