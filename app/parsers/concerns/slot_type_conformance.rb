# The RegRep shape chapter 4.6 asks of a received request: the `xsi:type` every
# slot value declares, the one every element of a collection declares, and what
# a collection must carry once it declares itself one.
#
# Apart from the parser, as `AgentConformance`, `RequirementConformance` and
# `ClassificationConformance` are, and for the reason the second states: the
# class does not fit the rules of a sixth subject.
#
# Refusals go through `refuse`, which the parser including this defines.
module SlotTypeConformance
  include OotsNamespaces

  # The slots of `query:QueryRequest`, each under the local name the rule that
  # types it asks for, and that rule. A local name and never a qualified one:
  # the nineteen assertions all read `substring-after(@xsi:type, ':')` and
  # compare what that yields.
  #
  # The context of each of these eleven is the `rim:SlotValue` of a slot that is
  # *there* — an absent slot triggers none of them, its presence being what
  # `R-EDM-REQ-S005` to `S016` count. Three of the nineteen sit one level lower,
  # and are in `COLLECTION_ELEMENT_TYPES` below.
  #
  # Keyed rather than paired, as `AgentConformance::RULES` is: a row written the
  # other way round would put a rule identifier where a type name is expected,
  # and the `detail` of an `EDM:ERR:0003` would stop naming a rule at all.
  QUERY_REQUEST_SLOT_TYPES = {
    'SpecificationIdentifier' => { type: 'StringValueType', rule: 'R-EDM-REQ-S020' },
    'IssueDateTime' => { type: 'DateTimeValueType', rule: 'R-EDM-REQ-S021' },
    'Procedure' => { type: 'StringValueType', rule: 'R-EDM-REQ-S022' },
    'PreviewLocation' => { type: 'StringValueType', rule: 'R-EDM-REQ-S023' },
    'PossibilityForPreview' => { type: 'BooleanValueType', rule: 'R-EDM-REQ-S024' },
    'ExplicitRequestGiven' => { type: 'BooleanValueType', rule: 'R-EDM-REQ-S025' },
    'Requirements' => { type: 'CollectionValueType', rule: 'R-EDM-REQ-S026' },
    'EvidenceRequester' => { type: 'CollectionValueType', rule: 'R-EDM-REQ-S028' },
    'EvidenceProvider' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S030' },
    'EvidenceProviderClassification' => { type: 'CollectionValueType', rule: 'R-EDM-REQ-S031' },
    'ReturnLocation' => { type: 'StringValueType', rule: 'R-EDM-REQ-S061' },
  }.freeze

  # What the 1.2 line makes of that table, the two lines typing their slots
  # alike but for these: `R-EDM-REQ-S022` asks an
  # `rim:InternationalStringValueType` of `Procedure` there — the only type any
  # of the nineteen assertions moved between the two tags — and `ReturnLocation`
  # is a slot 2.0.1 alone defines, so nothing types it here. Held to the 2.0
  # rules, a conformant 1.2 request would be refused for the shape its own line
  # prescribes.
  EARLIER_LINE_SLOT_TYPES = QUERY_REQUEST_SLOT_TYPES
    .except('ReturnLocation')
    .merge('Procedure' => { type: 'InternationalStringValueType', rule: 'R-EDM-REQ-S022' })
    .freeze

  # The slots of `query:Query`, every one of them an `rim:AnyValueType`: the
  # subject of the evidence, the evidence asked for, and the representative
  # chapter 4.5.1 provides for.
  QUERY_SLOT_TYPES = {
    'EvidenceRequest' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S033' },
    'LegalPerson' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S034' },
    'NaturalPerson' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S035' },
    'AuthorizedRepresentative' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S036' },
    'AuthorizedRepresentativeLegalPerson' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S055' },
  }.freeze

  # The three of the nineteen whose context is `…/rim:SlotValue/rim:Element` and
  # not the slot value itself: the elements of the three collections, each an
  # `rim:AnyValueType` too. The names are those of `QUERY_REQUEST_SLOT_TYPES`
  # and of no slot of `query:Query`, which carries no collection at all.
  COLLECTION_ELEMENT_TYPES = {
    'Requirements' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S027' },
    'EvidenceRequester' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S029' },
    'EvidenceProviderClassification' => { type: 'AnyValueType', rule: 'R-EDM-REQ-S032' },
  }.freeze

  # `R-EDM-REQ-S052` and `S053` read the attribute whole, prefix included — see
  # `require_conformant_collections`, which is the only place in this module
  # that compares anything but a local name.
  COLLECTION_VALUE_TYPE = 'rim:CollectionValueType'.freeze

  COLLECTION_TYPE = 'urn:oasis:names:tc:ebxml-regrep:CollectionType:Set'.freeze

  private

  # The table of the line the message is read in: the rules that type a slot are
  # those of its own version, as `R-EDM-REQ-C001` is.
  def slot_types
    specification.return_location_slot? ? QUERY_REQUEST_SLOT_TYPES : EARLIER_LINE_SLOT_TYPES
  end

  def require_conformant_slot_types
    typed = slot_types

    all(request, './rim:Slot').each do |slot|
      name = attribute(slot, 'name')
      require_slot_value_types(slot, name, typed)
      require_element_types(slot, name)
    end

    all(query, './rim:Slot').each { |slot| require_slot_value_types(slot, attribute(slot, 'name'), QUERY_SLOT_TYPES) }
  end

  # Every `rim:SlotValue` the slot carries and not the first alone: the rule's
  # context is the element, so a second one is judged as much as the first.
  # A slot no rule types — one the request invented — is passed over, there
  # being no assertion to break.
  def require_slot_value_types(slot, name, types)
    typed = types[name]
    return if typed.nil?

    all(slot, './rim:SlotValue').each do |value|
      require_declared_type(value, typed, 'parsers.evidence_request.slot_type_unexpected', name:)
    end
  end

  def require_element_types(slot, name)
    typed = COLLECTION_ELEMENT_TYPES[name]
    return if typed.nil?

    all(slot, './rim:SlotValue/rim:Element').each do |element|
      require_declared_type(element, typed, 'parsers.evidence_request.element_type_unexpected', name:)
    end
  end

  def require_declared_type(node, typed, key, name:)
    expected = typed.fetch(:type)
    declared = attribute(node, 'type', 'xsi')
    return if local_type(declared) == expected

    refuse(typed.fetch(:rule), key, name:, expected:, declared: announced(declared))
  end

  # What the sentence says of an attribute that is not there, in one place: the
  # two refusals of this module both name a value they may not have.
  def announced(declared) = declared.presence || I18n.t('parsers.evidence_request.unnamed_slot_type')

  # `substring-after(@xsi:type, ':')`, exactly: `rim:AnyValueType` yields
  # `AnyValueType`, `x:AnyValueType` yields the same — the prefix is not judged,
  # and requiring `rim:` would refuse what a FATAL rule admits — and
  # `AnyValueType` written without a prefix yields the empty string, which
  # matches no expected name. `a:b:c` yields `b:c`, the separator being the
  # first one.
  #
  # `partition(':').last` and not `split(':').last`, which would yield `c` there
  # and `AnyValueType` on a bare name — the mirror of the trap
  # `substring-before` sets, and the reason neither is to be « simplified » into
  # the other.
  def local_type(declared) = declared.to_s.partition(':').last

  # `R-EDM-REQ-S052` and `S053`, whose common context is
  # `rim:SlotValue[@xsi:type='rim:CollectionValueType']`.
  #
  # That comparison is literal, prefix included, where the nineteen rules above
  # compare the local name alone — the two readings of `@xsi:type` in this
  # module are deliberately different, and unifying them breaks one of the two:
  # made local, these would reach a slot value typed `x:CollectionValueType`
  # that their context does not select; made qualified, the others would refuse
  # a prefix the specification admits.
  #
  # No ancestor narrows the context either, so every `rim:SlotValue` of the
  # request is reached, wherever it sits.
  def require_conformant_collections
    all(request, './/rim:SlotValue').each do |value|
      next unless attribute(value, 'type', 'xsi') == COLLECTION_VALUE_TYPE

      refuse('R-EDM-REQ-S052', 'parsers.evidence_request.collection_without_element') if all(value, './rim:Element').empty?

      declared = attribute(value, 'collectionType')
      next if declared == COLLECTION_TYPE

      refuse('R-EDM-REQ-S053', 'parsers.evidence_request.collection_type_unexpected',
        expected: COLLECTION_TYPE, declared: announced(declared))
    end
  end
end
