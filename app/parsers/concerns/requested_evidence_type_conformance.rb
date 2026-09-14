# What chapter 4.6 asks of the `sdg:DataServiceEvidenceType` a received request
# asks for, in the parts of it France never hands to anyone: its identifier, the
# language of each of its descriptions, and the format of each distribution it
# names.
#
# The subject is the evidence type, and the cut against `EchoedValueConformance`
# — which walks this same element for `R-EDM-REQ-C027`, `C029` and `C028` — is
# by principle and not by element. There, the rules are applied because
# `app/templates/evidence_response.v2_0.xml.erb` copies the classification and
# the titles into the answer France signs, so a request breaking one and being
# answered would have France break its response twin. Here, nothing is copied:
# the response announces the format it *served* and never the one asked for —
# `EvidenceResponseBuilder#served_format` — the `sdg:Identifier` of the type is
# not echoed at all, and no template writes a description. These three are
# applied for the only reason left, which is that they are FATAL on a value the
# request carries.
#
# `R-EDM-REQ-S045`, which closes the list of children this element may have, is
# not here: it judges shape and never a value, so it belongs with the rest of
# the shape in `RegRepShapeConformance` — which is also where the path to this
# subtree is held, three readers now walking it.
#
# `R-EDM-REQ-C032`, which counts the distributions, is not here either: it is
# refused where the formats are read, because that count is what commands the
# reading — `EarlierLineConformance#require_counted_distributions` holds both
# lines of it.
#
# Apart from the parser, as the eight conformance modules beside it are, and for
# the reason `RequirementConformance` states: the class does not fit the rules
# of a tenth subject. `AgentConformance` is included for `require_language`
# alone, which holds any element the chapter obliges to name its language:
# `C031` and `C030` over a description are, word for word, the pair of
# assertions it already reads for an agent's name, a requirement's wordings and
# the titles of this very element.
#
# Refusals go through `refuse`, which the parser including this defines.
module RequestedEvidenceTypeConformance
  include OotsNamespaces
  include AgentConformance

  private

  # Every type the `EvidenceRequest` slot carries, no rule counting them, and
  # silence on a request carrying none: the contexts are the elements
  # themselves, so absence triggers no assertion — `RegRepShapeConformance`
  # refuses a slot value carrying no type at all, under `R-EDM-REQ-S044`, and
  # this reader has nothing to say about it.
  #
  # Walked from `query` rather than through `slot_content`, for the reason
  # `EarlierLineConformance#require_conformant_transformations` gives of the
  # same subtree.
  def require_conformant_requested_evidence_types
    all(query, RegRepShapeConformance::EVIDENCE_TYPES).each do |described|
      require_evidence_type_identifier(described)
      all(described, './sdg:Description').each { |description| require_language(description, :evidence_type_description) }
      require_published_formats(described)
    end
  end

  # `R-EDM-REQ-C106`, whose context is the evidence type and whose test is
  # `not(normalize-space(sdg:Identifier)='')`: an element written blank breaks
  # it, and so does one that is not there at all, `normalize-space` of an empty
  # sequence being the empty string. That absence is the case the schema leaves
  # open — `DataServiceEvidenceTypeType` gives `sdg:Identifier` `minOccurs="0"`
  # — and the rule closes.
  #
  # Not the identifier `EvidenceRequestParser#evidence_type` reads, which is the
  # `sdg:EvidenceTypeClassification` beside it: this one names the type in the
  # Evidence Broker's own terms and reaches nothing France writes.
  def require_evidence_type_identifier(described)
    return if text_at(described, './sdg:Identifier').to_s.squish.present?

    refuse('R-EDM-REQ-C106', 'parsers.evidence_request.evidence_type_without_identifier')
  end

  # `R-EDM-REQ-C033`, on the `sdg:Format` of every `sdg:DistributedAs` the type
  # names — each of them, the context carrying no position predicate, and a
  # distribution naming no format at all triggering nothing, its context being
  # the element.
  #
  # Compared exactly, the assertion carrying no `i` flag where the list
  # publishes lower case: `LanguageCode` holds the reason for the whole family.
  #
  # The value travels as `declared` and not as `format`, which `I18n` reserves
  # for its own use and raises on.
  #
  # This runs among the checks of `validate!`, so it refuses a format the
  # specification does not publish before `EvidenceProvision::ChooseAnswer` gets
  # to refuse, under `EDM:ERR:0007`, a published format France holds no document
  # in. `image/png` alone is the second; `application/foo` is this one.
  def require_published_formats(described)
    all(described, './sdg:DistributedAs/sdg:Format').each do |format|
      next if OotsMediaType.valid?(format.text)

      refuse('R-EDM-REQ-C033', 'parsers.evidence_request.evidence_type_format_unpublished',
        declared: format.text.presence || I18n.t('parsers.evidence_request.unnamed_format'),
        admitted: OotsMediaType::CODES.join(', '))
    end
  end
end
