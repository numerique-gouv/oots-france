# What chapter 4.6 fixes in the envelope of a received request, as opposed to
# in anything the request describes: the element the document opens on, and the
# four literals the chapter admits one value each for — the specification the
# request announces, the date it bears, the return type it asks of the registry
# and the query it names.
#
# The family is the envelope and not the rule's shape: `R-EDM-REQ-S001` and
# `S002` read the document element where the four others read a value, and what
# puts them together is that none of them says anything about the evidence
# asked for or the person it is about. They are what has to be true before the
# document is a request at all.
#
# None of these values is exploited. France answers with the evidence it holds,
# in the version the header settled, whatever `query:ResponseOption` asked for:
# they are read to be judged and for nothing else — which is why they are here
# and not among the readers of `EvidenceRequestParser`.
#
# Two entry points, because the refusals do not fall at the same moment.
# `require_query_request` is called from the constructor, the reading of
# `/query:QueryRequest` having come back empty, and its refusal carries no
# answer: a document that is not a query request names no requester to address,
# no identifier to echo and no version to answer in, so the journal is its only
# trace — which is why it names its rule there, `docs/journal_des_echanges.md`
# holding that a refusal whose reason is known and unrecorded cannot be
# justified afterwards. `require_conformant_envelope` is called among the checks
# of `validate!`, and everything it refuses does go back in an `EDM:ERR:0003`.
#
# Apart from the parser, as the seven conformance modules beside it are, and for
# the reason `RequirementConformance` states: the class does not fit the rules
# of a ninth subject.
#
# Refusals go through `refuse`, which the parser including this defines.
module RequestEnvelopeConformance
  include OotsNamespaces

  # `R-EDM-REQ-C002`, transcribed whole rather than tightened — the convention
  # `RequirementConformance::REQUIREMENT_IDENTIFIER` states. It carries neither
  # `^` nor `$`, so anything may surround the timestamp, and it stops at the
  # seconds: it measures the shape of a timestamp and not the whole of
  # `xsd:dateTime`, constraining neither the fraction of a second nor the time
  # zone. A reader asking for `xsd:dateTime` in full would refuse values the
  # rule accepts, which is the over-strictness this reader exists to undo.
  ISSUE_DATE_TIME = /[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}/

  # `R-EDM-REQ-C024` and `C025` admit one value each and no other. Both are the
  # RegRep way of saying what OOTS asks for once: the whole object, with the
  # document attached to it.
  #
  # Keyed by where the rule finds its context nodes, written from
  # `query:QueryRequest` down, each row carrying the attribute the rule reads,
  # the value it fixes and its identifier — the shape
  # `SlotTypeConformance::QUERY_REQUEST_SLOT_TYPES` uses, and for the same
  # reason: a row written the other way round would put a rule identifier where
  # a value is expected, and the `detail` of an `EDM:ERR:0003` would stop naming
  # a rule at all.
  FIXED_ATTRIBUTES = {
    './query:ResponseOption' => {
      attribute: 'returnType', value: 'LeafClassWithRepositoryItem', rule: 'R-EDM-REQ-C024',
      key: 'parsers.evidence_request.return_type_unexpected',
    }.freeze,
    './query:Query' => {
      attribute: 'queryDefinition', value: 'DocumentQuery', rule: 'R-EDM-REQ-C025',
      key: 'parsers.evidence_request.query_definition_unexpected',
    }.freeze,
  }.freeze

  private

  # The local name first and the namespace second, the order the two patterns
  # are published in. `name` is the local name in Nokogiri, where the assertion
  # says `local-name()` explicitly; and the root is fetched by `/*` rather than
  # through `Nokogiri::XML::Document#root`, so that this reads the document
  # element of whatever it is handed, as the rules' `/node()` does.
  def require_query_request(root)
    unless root&.name == 'QueryRequest'
      refuse('R-EDM-REQ-S001', 'parsers.evidence_request.not_a_query_request',
        root: root&.name.presence || I18n.t('parsers.evidence_request.unnamed_root'))
    end

    refuse('R-EDM-REQ-S002', 'parsers.evidence_request.request_namespace_unexpected',
      namespace: root.namespace&.href.presence || I18n.t('parsers.evidence_request.unnamed_namespace'),
      expected: NAMESPACES.fetch('query'))
  end

  # The specification first, which is the literal the rest of the reading
  # depends on: every other rule of the chapter is applied in the shape of the
  # line the message announces, so a request whose announced version is not the
  # one it is being read in is refused before anything is judged by the wrong
  # line's table. No rule of the chapter fixes that order.
  def require_conformant_envelope
    require_expected_specification
    require_issue_date_time
    require_fixed_attributes
  end

  # Against the version the message was read in, which is the ebMS property when
  # the header carries one: a slot contradicting it is the inconsistency chapter
  # 4.7 §2.6.2 has the receiver refuse, and it is refused under the rule of the
  # line the header announced. A message with no property is read in the version
  # of its own slot, so this only fires there on a version France does not
  # speak, `EdmSpecification.resolve` having fallen back on the preferred one.
  def require_expected_specification
    declared = text_at(request, "./rim:Slot[@name='SpecificationIdentifier']/rim:SlotValue/rim:Value")
    return if declared == specification.identifier

    refuse('R-EDM-REQ-C001', 'parsers.evidence_request.unexpected_specification',
      announced: declared.presence || I18n.t('parsers.evidence_request.unnamed_specification'),
      expected: specification.identifier)
  end

  # The context is the `rim:Value` itself, so an absent slot triggers nothing:
  # `R-EDM-REQ-S006` is what counts it, and `SlotReading#slot_value` what
  # refuses one written empty. Every value is judged and not the first alone,
  # the assertion carrying no position predicate.
  #
  # `squish` is the `normalize-space` the assertion applies before matching.
  def require_issue_date_time
    all(request, "./rim:Slot[@name='IssueDateTime']/rim:SlotValue/rim:Value").each do |value|
      declared = value.text.squish
      next if declared.match?(ISSUE_DATE_TIME)

      refuse('R-EDM-REQ-C002', 'parsers.evidence_request.issue_date_time_malformed',
        date: declared.presence || I18n.t('parsers.evidence_request.unnamed_date'))
    end
  end

  # Each context is the element carrying the attribute, so a request omitting
  # `query:ResponseOption` breaks no rule here — the schema is what requires it,
  # and `query` is what refuses a request with no `query:Query` at all. Every
  # element is judged, for the reason above.
  def require_fixed_attributes
    FIXED_ATTRIBUTES.each do |path, fixed|
      all(request, path).each do |node|
        declared = attribute(node, fixed.fetch(:attribute))
        next if declared == fixed.fetch(:value)

        refuse(fixed.fetch(:rule), fixed.fetch(:key), expected: fixed.fetch(:value),
          declared: declared.presence || I18n.t('parsers.evidence_request.unnamed_value'))
      end
    end
  end
end
