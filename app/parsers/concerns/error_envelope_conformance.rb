# What chapter 4.6 fixes in the envelope of a received error report, as opposed
# to in the exception it carries or the agents it names: the element the
# document opens on, the slots it must and may hold, the two identifiers that
# correlate it, and the version it announces.
#
# Read and never refused, like every rule this parser confronts a report to:
# `ErrorResponseParser#violations` says why, and the journal is the whole of
# what these change.
#
# Every context is written absolutely, from the document element down, as the
# Schematron writes them — and everything but `-S001` and `-S002` is read
# through `declared_response`, which is nil where the root is something else:
# such a document opens none of those contexts, and `-S001` is the rule that
# says so.
#
# Apart from the parser, as the four conformance modules beside it are: the
# fifty-seven rules of this chapter do not fit one class, `Metrics/ClassLength`
# capping it at 150.
#
# `document`, `declared_response`, `violation` and `named` are the includer's.
# The first is what `-S001` and `-S002` need and the second cannot give: their
# whole point is to judge a document that is no `query:QueryResponse`.
module ErrorEnvelopeConformance
  include OotsNamespaces

  RESPONSE = '/query:QueryResponse'.freeze

  # The one value `-S006` admits, and the status `C011` narrows its own context
  # to.
  FAILURE = 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure'.freeze

  REQUESTER_SLOT = 'EvidenceRequester'.freeze

  # `-S009` to `-S011`, one rule per slot, each counting exactly one: two of the
  # same name leave which one is meant undecided. `-S012` counts the requester's
  # the same way under `CAUTION`, which is why that slot is not here.
  REQUIRED_SLOTS = {
    'SpecificationIdentifier' => 'R-EDM-ERR-S009',
    'EvidenceResponseIdentifier' => 'R-EDM-ERR-S010',
    'ErrorProvider' => 'R-EDM-ERR-S011',
  }.freeze

  # What `-S017` admits under `query:QueryResponse`, and nothing else.
  ADMITTED_SLOTS = [*REQUIRED_SLOTS.keys, REQUESTER_SLOT].freeze

  # `-S004` and `C002`, copied from the Schematron and not tightened — the
  # convention `EvidenceResponseParser::REQUEST_IDENTIFIER` states, and written
  # out here for the reason stated there: what these two have in common with the
  # response's is the wording of the TDD, not a decision this repository takes
  # once. The attribute carries the `urn:uuid:` prefix and the slot does not.
  REQUEST_IDENTIFIER = /\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i
  RESPONSE_IDENTIFIER = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # The one type `C025` admits where the report correlates no request, compared
  # as the assertion compares it — raw, prefix included. The prefix identifies
  # no namespace, per `OotsNamespaces`, and the rule compares the attribute's
  # string all the same: reading it as a namespace would be reading something
  # the rule does not say.
  INVALID_REQUEST_TYPE = 'rs:InvalidRequestExceptionType'.freeze

  # Chapter 4.5.3 §2 makes the `EvidenceRequester` slot `0..1` and « MUST be
  # present unless the rs:exception/@xsi:type 'InvalidRequestExceptionType' is
  # used ». No FATAL assertion executes either half — `-S012` counts the slot
  # under `CAUTION` — so the detail names the source that does, as
  # `AgentConformance::AGENT_NAME_REQUIRED` does for the request.
  REQUESTER_SLOT_REQUIRED = 'TDD 4.5.3 §2: EvidenceRequester slot required unless InvalidRequestExceptionType'.freeze

  REQUESTER_SLOT_SINGLE = 'TDD 4.5.3 §2: EvidenceRequester slot 0..1'.freeze

  private

  def envelope_violations(judged)
    return malformed_root if declared_response.nil?

    [*malformed_root, *declared_envelope(judged)]
  end

  def declared_envelope(judged)
    [
      *missing_slots,
      *unexpected_specification(judged),
      unexpected_status,
      object_list_in_a_failure,
      *failure_without_exception,
      *unexpected_slots,
      malformed_request_id,
      *malformed_response_id,
      uncorrelated_without_invalid_request,
      *requester_slot_cardinality,
    ]
  end

  # `-S001` and `-S002`, two assertions on `/node()` and therefore independent
  # of one another: a `query:QueryRequest` delivered as an error report breaks
  # the first alone, its namespace being the very one the second asks for.
  #
  # The root is fetched by `/*` rather than through `Nokogiri::XML::Document#root`,
  # so that this reads the document element of whatever it is handed, as the
  # rules' `/node()` does.
  def malformed_root
    root = at(document, '/*')

    [unexpected_root_name(root), unexpected_root_namespace(root)]
  end

  def unexpected_root_name(root)
    return if root&.name == 'QueryResponse'

    violation('R-EDM-ERR-S001', 'root_not_a_query_response', root: named(root&.name, 'unnamed_root'))
  end

  def unexpected_root_namespace(root)
    declared = root&.namespace&.href
    return if declared == NAMESPACES.fetch('query')

    violation('R-EDM-ERR-S002', 'root_namespace_unexpected',
      namespace: named(declared, 'unnamed_namespace'), expected: NAMESPACES.fetch('query'))
  end

  def missing_slots
    REQUIRED_SLOTS.filter_map do |name, rule|
      violation(rule, 'slot_required', name:) unless named_slots(name).one?
    end
  end

  # `C001`, whose context is the `rim:SlotValue` and not the slot: a report
  # carrying none opens it nowhere, and one carrying two is judged twice. The
  # test is a node-set comparison of `rim:Value`, so a value element missing
  # breaks it and one of two matching satisfies it — and it compares the string
  # as it stands, no `normalize-space` preceding it.
  #
  # Judged against the line of the exchange, as `R-EDM-RESP-C002` is.
  def unexpected_specification(expected)
    all(declared_response, "./rim:Slot[@name='SpecificationIdentifier']/rim:SlotValue").filter_map do |value|
      next if all(value, './rim:Value').any? { |declared| declared.text == expected.identifier }

      violation('R-EDM-ERR-C001', 'unexpected_specification',
        announced: named(text_at(value, './rim:Value'), 'absent_specification'), expected: expected.identifier)
    end
  end

  # `-S006`, which asserts the one value and therefore reports an absent status
  # too: XPath compares a missing attribute as an empty node set.
  def unexpected_status
    declared = attribute(declared_response, 'status')
    return if declared == FAILURE

    violation('R-EDM-ERR-S006', 'unexpected_status', announced: named(declared, 'absent_value'))
  end

  # `-S007`: an unsuccessful response carries no object list. No status filter
  # on the context — the rule is asserted of every `query:QueryResponse` this
  # Schematron is run against, and this one is only ever run against a report.
  def object_list_in_a_failure
    return if at(declared_response, './rim:RegistryObjectList').nil?

    violation('R-EDM-ERR-S007', 'object_list_in_a_failure')
  end

  # `-S008` and `C011`, one and the same test asserted twice: the first of every
  # report, the second of one whose status announces a failure. A report
  # carrying no exception therefore names both where the status is right, and
  # `-S008` alone where it is not.
  def failure_without_exception
    return [] if exceptions.any?

    [
      violation('R-EDM-ERR-S008', 'response_without_exception'),
      (violation('R-EDM-ERR-C011', 'failure_without_exception') if attribute(declared_response, 'status') == FAILURE),
    ]
  end

  # `-S017`, whose test counts the slots whose `@name` is none of the four. A
  # slot carrying no name at all is not among them: XPath compares its missing
  # attribute as an empty node set, so every `@name!='…'` is false of it.
  def unexpected_slots
    all(declared_response, './rim:Slot').filter_map do |slot|
      declared = attribute(slot, 'name')
      next if declared.nil? || ADMITTED_SLOTS.include?(declared)

      violation('R-EDM-ERR-S017', 'unexpected_slot', name: declared)
    end
  end

  # `-S004`, asserted against the attribute node itself: a report carrying no
  # `@requestId` gives it nothing to match and leaves it silent — `-S003` is
  # what has something to say there, and it is `CAUTION`.
  #
  # `squish` is the `normalize-space` the assertion applies before matching.
  def malformed_request_id
    declared = attribute(declared_response, 'requestId')
    return if declared.nil? || declared.squish.match?(REQUEST_IDENTIFIER)

    violation('R-EDM-ERR-S004', 'request_id_not_a_uuid', id: named(declared.squish, 'absent_value'))
  end

  # `C002`, on the bare UUID the slot carries — the `urn:uuid:` prefix belongs
  # to the attribute above and to nothing else here. Its context is the
  # `rim:Value`, so a slot carrying none opens it nowhere and every value that
  # is there is judged.
  def malformed_response_id
    all(declared_response, "./rim:Slot[@name='EvidenceResponseIdentifier']/rim:SlotValue/rim:Value").filter_map do |value|
      declared = value.text.squish
      next if declared.match?(RESPONSE_IDENTIFIER)

      violation('R-EDM-ERR-C002', 'response_id_not_a_uuid', id: named(declared, 'absent_value'))
    end
  end

  # `C025`: a report that correlates no request says so by the one exception
  # type chapter 4.5.3 reserves for it. The test is a node-set comparison, so
  # one exception of that type among several satisfies it, exactly as written.
  def uncorrelated_without_invalid_request
    return if attribute(declared_response, 'requestId') || invalid_request?

    violation('R-EDM-ERR-C025', 'uncorrelated_without_invalid_request', type: INVALID_REQUEST_TYPE)
  end

  # The two halves of what chapter 4.5.3 §2 says of the requester's slot, which
  # no FATAL assertion executes. The exemption is read as the table words it —
  # the exception type that was *used* — so a report carrying several is exempt
  # the moment one of them is an invalid request, as `C025` reads the same
  # condition.
  def requester_slot_cardinality
    found = named_slots(REQUESTER_SLOT)

    [
      (violation(REQUESTER_SLOT_SINGLE, 'slot_doubled', name: REQUESTER_SLOT) if found.size > 1),
      (violation(REQUESTER_SLOT_REQUIRED, 'requester_slot_missing') if found.empty? && !invalid_request?),
    ]
  end

  # Whether the report carries the one exception type chapter 4.5.3 reserves for
  # one correlating no request: the condition `C025` tests, and the exemption
  # the chapter's own table grants the requester's slot.
  def invalid_request?
    exceptions.any? { |found| attribute(found, 'type', 'xsi') == INVALID_REQUEST_TYPE }
  end

  def exceptions = all(declared_response, './rs:Exception')

  # Where the rules count slots rather than look one up: `find_slot` stops at
  # the first, which is exactly the cardinality they are checking.
  def named_slots(name) = all(declared_response, "./rim:Slot[@name='#{name}']")
end
