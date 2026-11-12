# One answer of a directory, kept as it was signed: the parsers that read the
# directories live read it back, refusals included.
class DirectorySnapshot
  class Answer < ApplicationRecord
    belongs_to :directory_snapshot

    # The parameters alone, `queryId` among them, which is what tells the two
    # Evidence Broker queries apart: a key naming the parser would leave the
    # copy unreadable the day a parser is renamed, until the next sweep.
    def self.key(parameters)
      Digest::SHA256.hexdigest(parameters.to_h.transform_keys(&:to_s).sort.to_json)
    end
  end
end
