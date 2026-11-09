# One family of the rules chapter 4.6 applies to a received request, judged on
# its own: the `query:QueryRequest` and the version it is read in are all a
# family needs, and `validate!` refuses the first rule of the family it finds
# broken.
#
# `EvidenceRequestParser#validate!` builds each family at its rank and judges
# it there. The order of the families is significant — the first refusal is the
# one the correspondent receives — so it is the parser's to keep, and no family
# decides it. Three families also answer the parser outside `validate!`, each
# header saying when: `RequestEnvelopeConformance`, `EarlierLineConformance` and
# `PreviewConformance`. `WordingConformance` alone is handed more than the
# request.
class RequestConformance
  include SlotReading
  include QueryRequestReading

  def initialize(request, specification:)
    @request = request
    @specification = specification
  end

  private

  attr_reader :request, :specification
end
