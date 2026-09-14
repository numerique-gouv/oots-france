# The RegRep shape chapter 4.6 asks of a received request: which slots it may
# carry at all, that each of them holds one slot value with something in it, the
# `xsi:type` every slot value and every element of a collection declares, what a
# collection must carry once it declares itself one, and the `sdg:` element each
# slot of `query:Query` puts under its value.
#
# **Shape, and never a value.** Nothing here reads what a slot says — that is
# `RequestEnvelopeConformance` for the literals of the envelope,
# `DescribedPersonConformance` for the people, `EchoedValueConformance` for what
# the answer copies out. These rules would refuse a document whose every value
# was conformant and whose structure was not, and they are the ones that can be
# applied without knowing what any of it means.
#
# Apart from the parser, as `AgentConformance`, `RequirementConformance` and
# `ClassificationConformance` are, and for the reason the second states: the
# class does not fit the rules of a sixth subject.
#
# Refusals go through `refuse`, which the parser including this defines.
module RegRepShapeConformance
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

  # The `sdg:` element `R-EDM-REQ-S044`, `S046`, `S047`, `S048` and `S056` each
  # put under the slot value of one slot of `query:Query` — the five slots
  # `QUERY_SLOT_TYPES` types, judged here on what they carry rather than on what
  # they declare themselves to be.
  #
  # A local name, the assertions testing `sdg:Person` and its like against the
  # `p4s` namespace, which `NAMESPACES` binds by URI. The evidence subject
  # travels as an `sdg:Person` in a request and as an `sdg:NaturalPerson` in a
  # response, where an organisation is an `sdg:LegalPerson` on both sides: the
  # symmetry between the two messages stops at the slot, which is why this table
  # is written out rather than derived from anything the response knows.
  QUERY_SLOT_CONTENTS = {
    'EvidenceRequest' => { element: 'DataServiceEvidenceType', rule: 'R-EDM-REQ-S044' },
    'LegalPerson' => { element: 'LegalPerson', rule: 'R-EDM-REQ-S047' },
    'NaturalPerson' => { element: 'Person', rule: 'R-EDM-REQ-S046' },
    'AuthorizedRepresentative' => { element: 'Person', rule: 'R-EDM-REQ-S048' },
    'AuthorizedRepresentativeLegalPerson' => { element: 'LegalPerson', rule: 'R-EDM-REQ-S056' },
  }.freeze

  # What `R-EDM-REQ-S045` admits under the `sdg:DataServiceEvidenceType` of an
  # `EvidenceRequest` slot, and nothing else — identical at both tags. Its
  # assertion adds up the elements it names and compares the total to
  # `count(child::*)`, so it closes the list by counting rather than by testing
  # each child, and an element of another namespace carrying one of these local
  # names is counted by the second and not by the first: it is refused.
  #
  # This is narrower than the schema, on both lines, and deliberately so. The
  # `sdg` XSD gives `DataServiceEvidenceTypeType` an `AccessService`, an
  # `AuthenticationLevelOfAssurance` and any number of `sdg:Note` and
  # `sdg:EvidenceProviderClassification` besides these five — and, in the 1.2.0
  # profile, the `sdg:EvidenceProviderJurisdictionDetermination` that is its only
  # home there. The rule names none of them, so a schema-valid request carrying
  # any is refused. The `.sch` is what plays where the two disagree, being the
  # executable form of the rules and the one the Commission's own test services
  # run — `docs/carte_des_tdd.md` states that arbitration and records this
  # disagreement.
  #
  # One consequence is worth following through: `WordingConformance`'s 1.2 table
  # measures `sdg:JurisdictionContext` and `sdg:JurisditionLevel`, which live
  # under that determination and nowhere else, so no request this rule admits
  # can reach them.
  ADMITTED_EVIDENCE_TYPE_CHILDREN = %w[
    Identifier EvidenceTypeClassification Title Description DistributedAs
  ].freeze

  # Where the rules on the evidence type asked for find their context nodes,
  # written from `query:Query` down. Held here, where `QUERY_SLOT_CONTENTS` says
  # what sits under which slot, and read from here by the two modules that judge
  # what the type carries — `RequestedEvidenceTypeConformance` and
  # `EchoedValueConformance`. One literal for three walks over one subtree: three
  # copies would be free to drift.
  EVIDENCE_TYPES = "./rim:Slot[@name='EvidenceRequest']/rim:SlotValue/sdg:DataServiceEvidenceType".freeze

  private

  # The table of the line the message is read in: the rules that type a slot are
  # those of its own version, as `R-EDM-REQ-C001` is.
  def slot_types
    specification.return_location_slot? ? QUERY_REQUEST_SLOT_TYPES : EARLIER_LINE_SLOT_TYPES
  end

  # The precise refusals first and the generic net last, which is the order
  # `EvidenceRequestParser#require_conformant_document` gives its own three
  # walks and for the same reason: a slot value declaring itself a collection
  # and carrying nothing breaks `R-EDM-REQ-S052`, which says what a collection
  # must carry, and `S051`, which says that no slot value at all may be empty —
  # and the first names its subject where the second only names a shape. So
  # `require_counted_slot_values` is the floor under everywhere the four readers
  # above do not reach. No rule of the chapter fixes that order.
  def require_conformant_shape
    require_admitted_names
    require_conformant_slot_types
    require_conformant_collections
    require_slot_contents
    require_counted_slot_values
  end

  # `R-EDM-REQ-S019` and `S049` close the list of slots each level admits, and
  # `S045` the list of elements an evidence type may carry.
  #
  # The two slot lists are the keys of the typing tables, derived and not
  # transcribed a second time: `S019` names these slots to close the list where
  # `S020` to `S061` name them to type each one, so the two rules enumerate one
  # and the same set — including on the 1.2 line, which drops `ReturnLocation`
  # from both. A list copied out by hand would be free to drift from the table
  # beside it in silence, which is the reason
  # `WordingConformance::EARLIER_LINE_MINIMUM_LENGTHS` derives its own.
  def require_admitted_names
    require_admitted_slots(request, slot_types.keys, 'R-EDM-REQ-S019')
    require_admitted_slots(query, QUERY_SLOT_TYPES.keys, 'R-EDM-REQ-S049')

    all(query, EVIDENCE_TYPES).each { |described| require_admitted_children(described) }
  end

  def require_admitted_slots(scope, admitted, rule)
    all(scope, './rim:Slot').each do |slot|
      name = attribute(slot, 'name')
      next if admitted.include?(name)

      refuse(rule, 'parsers.evidence_request.slot_name_unexpected',
        name: name.presence || I18n.t('parsers.evidence_request.unnamed_slot'),
        admitted: admitted.join(', '))
    end
  end

  # Counted as the assertion counts, and not tested child by child: the total of
  # the five admitted names against the total of the children. What that catches
  # and a list of names would not is an element of another namespace sharing one
  # of those local names — `sdg:` binds by URI here, so such a child adds to the
  # second count and not to the first.
  def require_admitted_children(described)
    admitted = ADMITTED_EVIDENCE_TYPE_CHILDREN.sum { |name| all(described, "./sdg:#{name}").size }
    declared = all(described, './*')
    return if admitted == declared.size

    refuse('R-EDM-REQ-S045', 'parsers.evidence_request.evidence_type_child_unexpected',
      children: declared.map(&:name).uniq.join(', '),
      admitted: ADMITTED_EVIDENCE_TYPE_CHILDREN.join(', '))
  end

  # `R-EDM-REQ-S050` and `S051`, whose contexts are a bare `rim:Slot` and a bare
  # `rim:SlotValue`: no ancestor narrows either, so every slot of the document is
  # counted and every slot value of it is weighed, wherever they sit — those of
  # `query:Query` as much as those of the request.
  #
  # `= 1` and not `>= 1` for the first, as the assertion has it: a slot carrying
  # two values leaves which one is meant undecided, which is the same reason the
  # rules counting the slots themselves count `= 1`.
  #
  # `count(child::*) > 0` for the second — element children, so a slot value
  # holding text and nothing else is empty to the rule.
  def require_counted_slot_values
    all(request, './/rim:Slot').each { |slot| require_one_slot_value(slot) }
    all(request, './/rim:SlotValue').each { |value| require_filled_slot_value(value) }
  end

  def require_one_slot_value(slot)
    declared = all(slot, './rim:SlotValue')
    return if declared.one?

    refuse('R-EDM-REQ-S050', 'parsers.evidence_request.slot_value_not_alone',
      name: slot_name(slot), count: declared.size)
  end

  def require_filled_slot_value(value)
    return unless all(value, './*').empty?

    refuse('R-EDM-REQ-S051', 'parsers.evidence_request.slot_value_empty', name: slot_name(value.parent))
  end

  # What each slot of `query:Query` must put under its value. The context is the
  # slot value of a slot that is *there*, so an absent slot triggers nothing:
  # `R-EDM-REQ-S015` counts `EvidenceRequest` and `S016` the two that name the
  # subject. Every slot value is judged, none of the five assertions carrying a
  # position predicate.
  #
  # This is what refuses, under its own rule, the absence `SlotReading#slot_content`
  # refuses naming none — and it runs among the checks of `validate!`, which
  # every reader of those slots is called after.
  def require_slot_contents
    all(query, './rim:Slot').each do |slot|
      carried = QUERY_SLOT_CONTENTS[attribute(slot, 'name')]
      next if carried.nil?

      all(slot, './rim:SlotValue').each do |value|
        next if at(value, "./sdg:#{carried.fetch(:element)}")

        refuse(carried.fetch(:rule), 'parsers.evidence_request.slot_value_without_element',
          name: slot_name(slot), element: "sdg:#{carried.fetch(:element)}")
      end
    end
  end

  def slot_name(slot) = attribute(slot, 'name').presence || I18n.t('parsers.evidence_request.unnamed_slot')

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
  # A slot the table does not type is passed over here — `require_admitted_names`
  # is what refuses it, under the rule that closes the list, and it has already
  # run.
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
