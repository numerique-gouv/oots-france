# The shape of the RegRep slots a received error report is made of, as opposed
# to what they say: which `xsi:type` each slot value declares, and the two
# generic patterns chapter 4.6 applies to every slot of the document.
#
# Read and never refused, like every rule this parser confronts a report to:
# `ErrorResponseParser#violations` says why.
#
# Apart from the parser, as the four conformance modules beside it are, and for
# the reason `ErrorEnvelopeConformance` states.
#
# `document`, `specification`, `violation` and `named` are the includer's.
module ErrorRegRepShapeConformance
  include OotsNamespaces

  # `-S018` to `-S024`, keyed by the context each hangs on and written as the
  # Schematron writes it: the four slots of the response anchor on
  # `query:QueryResponse`, the timestamp on the exception below it, and the two
  # preview slots on `rs:Exception` with no ancestor named.
  #
  # Keyed by context and carrying the type and the identifier, the shape
  # `RequestEnvelopeConformance::FIXED_ATTRIBUTES` uses and for the same reason:
  # a row written the other way round would put a rule identifier where a value
  # is expected.
  SLOT_TYPES = {
    "/query:QueryResponse/rim:Slot[@name='SpecificationIdentifier']" =>
      { type: 'StringValueType', rule: 'R-EDM-ERR-S018' }.freeze,
    "/query:QueryResponse/rim:Slot[@name='EvidenceResponseIdentifier']" =>
      { type: 'StringValueType', rule: 'R-EDM-ERR-S019' }.freeze,
    "/query:QueryResponse/rim:Slot[@name='ErrorProvider']" =>
      { type: 'AnyValueType', rule: 'R-EDM-ERR-S020' }.freeze,
    "/query:QueryResponse/rim:Slot[@name='EvidenceRequester']" =>
      { type: 'AnyValueType', rule: 'R-EDM-ERR-S021' }.freeze,
    "/query:QueryResponse/rs:Exception/rim:Slot[@name='Timestamp']" =>
      { type: 'DateTimeValueType', rule: 'R-EDM-ERR-S022' }.freeze,
    "//rs:Exception/rim:Slot[@name='PreviewLocation']" =>
      { type: 'StringValueType', rule: 'R-EDM-ERR-S023' }.freeze,
    "//rs:Exception/rim:Slot[@name='PreviewDescription']" =>
      { type: 'InternationalStringValueType', rule: 'R-EDM-ERR-S024' }.freeze,
  }.freeze

  # `-S025`, which types the slot 2.0 retired. Derived by `merge` and not
  # rewritten, as `WordingConformance::EARLIER_LINE_MINIMUM_LENGTHS` is: a
  # second table copied out by hand would drift from the first in silence.
  EARLIER_LINE_SLOT_TYPES = SLOT_TYPES.merge(
    "//rs:Exception/rim:Slot[@name='PreviewMethod']" =>
      { type: 'StringValueType', rule: 'R-EDM-ERR-S025' }.freeze,
  ).freeze

  private

  def shape_violations
    [*mistyped_slot_values, *slots_without_one_value, *values_without_content]
  end

  # Judged on the local part of the `xsi:type` alone, which is what the
  # assertions compare — `substring-after(@xsi:type, ':')`, and so the part
  # after the *first* colon. The prefix is bound in the document and identifies
  # nothing on its own, per `OotsNamespaces`, so `foo:DateTimeValueType`
  # satisfies `-S022` as the rule is written.
  #
  # A slot value carrying no `xsi:type` breaks its rule: `substring-after` of an
  # empty string is the empty string, which no type name equals.
  def mistyped_slot_values
    slot_types.flat_map { |path, expected| mistyped_values_at(path, expected) }
  end

  def mistyped_values_at(path, expected)
    all(document, "#{path}/rim:SlotValue").filter_map do |value|
      declared = attribute(value, 'type', 'xsi').to_s.partition(':').last
      next if declared == expected.fetch(:type)

      violation(expected.fetch(:rule), 'slot_value_mistyped', name: slot_name(value.parent),
        declared: named(declared, 'absent_value'), expected: expected.fetch(:type))
    end
  end

  # `-S028`, whose context is every `rim:Slot` of the document, whatever it
  # holds and wherever it sits: two slot values break it as surely as none.
  def slots_without_one_value
    all(document, '//rim:Slot').reject { |slot| all(slot, './rim:SlotValue').one? }
      .map { |slot| violation('R-EDM-ERR-S028', 'slot_without_one_value', name: slot_name(slot)) }
  end

  # `-S029`, its counterpart one level down: `count(child::*) > 0` counts
  # element children, so a slot value carrying text alone carries nothing.
  def values_without_content
    all(document, '//rim:SlotValue').select { |value| value.elements.empty? }
      .map { |value| violation('R-EDM-ERR-S029', 'slot_value_without_content', name: slot_name(value.parent)) }
  end

  def slot_types = specification.preview_method_slot? ? EARLIER_LINE_SLOT_TYPES : SLOT_TYPES

  # A slot by its `@name` rather than by its element name, which is `Slot` for
  # every one of them and would name nothing.
  def slot_name(slot) = named(attribute(slot, 'name'), 'unnamed_slot')
end
