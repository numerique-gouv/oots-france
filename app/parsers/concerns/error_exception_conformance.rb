# What chapter 4.6 asks of the `rs:Exception` a received error report carries:
# the four attributes that say which of the eight errors it is and how grave,
# and the three slots it may hold — the timestamp, and the two that send the
# user to a preview space.
#
# Read and never refused, like every rule this parser confronts a report to:
# `ErrorResponseParser#violations` says why.
#
# Two contexts, not one, and the split is the Schematron's: `-S013` hangs on
# `rs:Exception` with no ancestor named, where `C012` and the rest are written
# from `query:QueryResponse` down. What the first judges of a document opening
# on something else, the second says nothing of.
#
# Apart from the parser, as the four conformance modules beside it are, and for
# the reason `ErrorEnvelopeConformance` states.
#
# `document`, `declared_response`, `specification`, `violation` and `named` are
# the includer's.
module ErrorExceptionConformance
  include OotsNamespaces

  # The `EDMErrorCodes` code list, in the two columns the rules compare to:
  # `C013` reads its `name-Type`, `C017` its `code`. `EdmException::ALL` is that
  # list transcribed, and each rule reads one column of it.
  EXCEPTION_TYPES = EdmException::ALL.map(&:type).freeze
  EXCEPTION_CODES = EdmException::ALL.map(&:code).freeze

  # The `ErrorSeverity` code list, and the one value `C014` strikes out of it —
  # the severity the DSD error response uses, which this transaction does not.
  # What is left is `EdmException::ERROR` and `PREVIEW_REQUIRED`.
  ADDITIONAL_INPUT = 'urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:DSDErrorResponse:AdditionalInput'.freeze
  SEVERITIES = [EdmException::ERROR, ADDITIONAL_INPUT, EdmException::PREVIEW_REQUIRED].freeze

  # The code `C015` exempts, and the type the published sentence of `C022` asks
  # for beside the severity — one and the same error of the code list.
  PREVIEW_CODE = EdmException::AUTHORIZATION.code
  PREVIEW_TYPE = EdmException::AUTHORIZATION.type

  # `C012`, `C016` and `C026`, three assertions of one shape on one context:
  # each requires an attribute and says nothing of its value.
  ATTRIBUTES_REQUIRED = {
    'xsi:type' => 'R-EDM-ERR-C012', 'message' => 'R-EDM-ERR-C016', 'code' => 'R-EDM-ERR-C026',
  }.freeze

  # `C018`, transcribed whole rather than tightened — the convention
  # `RequestEnvelopeConformance::ISSUE_DATE_TIME` states. It carries neither `^`
  # nor `$`, so anything may surround the timestamp, and it stops at the
  # seconds: it measures the shape of a timestamp and not the whole of
  # `xsd:dateTime`.
  TIMESTAMP = /[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}/

  # `C019`, which asks for the scheme of the address and nothing else. What
  # follows one is another question: `ErrorResponseParser::ACCEPTED_SCHEMES`
  # admits `http` too, an address France refuses to follow being exactly the one
  # a dispute will be about.
  SECURE_SCHEME = 'https://'.freeze

  TIMESTAMP_SLOT = 'Timestamp'.freeze
  PREVIEW_LOCATION = 'PreviewLocation'.freeze
  PREVIEW_DESCRIPTION = 'PreviewDescription'.freeze
  PREVIEW_METHOD = 'PreviewMethod'.freeze

  # What `-S027` admits under an `rs:Exception`. The 1.2 line admits a fourth
  # beside them, `PreviewMethod` being the slot 2.0 retired.
  ADMITTED_SLOTS = [TIMESTAMP_SLOT, PREVIEW_LOCATION, PREVIEW_DESCRIPTION].freeze
  EARLIER_LINE_ADMITTED_SLOTS = [*ADMITTED_SLOTS, PREVIEW_METHOD].freeze

  # The three HTTP verbs `C021` admits of a `PreviewMethod`, on the 1.2 line
  # alone.
  PREVIEW_METHODS = %w[GET POST PUT].freeze

  # Chapter 4.5.3 §2 makes both preview slots `0..1`. No FATAL rule counts them
  # — `-S014` and `-S015` do it under `CAUTION` — so the detail names the source
  # that does, as `AgentConformance::AGENT_NAME_REQUIRED` does for the request.
  PREVIEW_SLOT_SINGLE = 'TDD 4.5.3 §2: PreviewLocation and PreviewDescription 0..1'.freeze

  private

  def exception_violations
    [
      *all(document, '//rs:Exception').flat_map { |found| exception_structure(found) },
      *reported_exceptions.flat_map { |found| exception_content(found) },
    ]
  end

  # What is asked of any `rs:Exception`, wherever it sits: the slot `-S013`
  # counts, and the two the chapter holds to one.
  def exception_structure(found)
    [*timestamp_violations(found), *doubled_preview_slots(found)]
  end

  def exception_content(found)
    [
      *missing_attributes(found),
      unexpected_type(found),
      unexpected_code(found),
      unexpected_severity(found),
      severity_of_an_ordinary_error(found),
      *unexpected_exception_slots(found),
      *insecure_preview_locations(found),
      *preview_without_authorisation(found),
      *preview_languages(found),
      *preview_method_violations(found),
    ]
  end

  def missing_attributes(found)
    ATTRIBUTES_REQUIRED.filter_map do |name, rule|
      violation(rule, 'exception_attribute_required', name:) if declared_attribute(found, name).nil?
    end
  end

  # `C013`, whose context is the attribute itself, so an exception carrying none
  # is judged by `C012` alone. The eight names are compared raw, prefix
  # included: the code list publishes them that way, and what prefix a document
  # binds is its own business.
  #
  # Named as the FATAL rule chapter 4.6 publishes it. The Schematron carries it
  # `role='ERROR'`, a role no other assertion of the corpus carries: a `.sch`
  # that contradicts the chapter it executes settles nothing, and
  # `docs/carte_des_tdd.md` records the discrepancy.
  def unexpected_type(found)
    declared = declared_attribute(found, 'xsi:type')
    return if declared.nil? || EXCEPTION_TYPES.include?(declared)

    violation('R-EDM-ERR-C013', 'exception_type_unexpected', type: declared)
  end

  def unexpected_code(found)
    declared = declared_attribute(found, 'code')
    return if declared.nil? || EXCEPTION_CODES.include?(declared)

    violation('R-EDM-ERR-C017', 'exception_code_unexpected', code: declared)
  end

  def unexpected_severity(found)
    declared = declared_attribute(found, 'severity')
    return if declared.nil? || (SEVERITIES.include?(declared) && declared != ADDITIONAL_INPUT)

    violation('R-EDM-ERR-C014', 'exception_severity_unexpected', severity: declared)
  end

  # `C015`, whose context filters on `@code != 'EDM:ERR:0002'`: an exception
  # carrying no code at all does not open it — XPath compares the missing
  # attribute as an empty node set — and neither does the authorisation error,
  # the one allowed to ask for a preview.
  #
  # `include?` and not a comparison: the assertion `matches` the severity
  # against that literal, which carries no metacharacter, so a value merely
  # containing it satisfies the rule.
  def severity_of_an_ordinary_error(found)
    declared = declared_attribute(found, 'code')
    severity = declared_attribute(found, 'severity')
    return if declared.nil? || declared == PREVIEW_CODE
    return if severity.to_s.include?(EdmException::ERROR)

    violation('R-EDM-ERR-C015', 'exception_severity_not_ordinary',
      severity: named(severity, 'absent_value'), expected: EdmException::ERROR)
  end

  # `-S013`, which counts the slot, and `C018`, which shapes every value it
  # carries: the second hangs on the `rim:Value`, so a slot that is missing or
  # carries none is reported by the first alone.
  def timestamp_violations(found)
    [
      (violation('R-EDM-ERR-S013', 'slot_required_in_exception', name: TIMESTAMP_SLOT) unless
        exception_slots(found, TIMESTAMP_SLOT).one?),
      *malformed_timestamps(found),
    ]
  end

  def malformed_timestamps(found)
    all(found, "./rim:Slot[@name='#{TIMESTAMP_SLOT}']/rim:SlotValue/rim:Value").filter_map do |value|
      declared = value.text.squish
      next if declared.match?(TIMESTAMP)

      violation('R-EDM-ERR-C018', 'timestamp_not_a_date_time', value: named(declared, 'absent_date'))
    end
  end

  # `-S027`, whose test counts the slots whose `@name` is none of those its line
  # admits. A slot carrying no name at all is not among them, for the reason
  # `ErrorEnvelopeConformance#unexpected_slots` gives.
  def unexpected_exception_slots(found)
    admitted = specification.preview_method_slot? ? EARLIER_LINE_ADMITTED_SLOTS : ADMITTED_SLOTS

    all(found, './rim:Slot').filter_map do |slot|
      declared = attribute(slot, 'name')
      next if declared.nil? || admitted.include?(declared)

      violation('R-EDM-ERR-S027', 'unexpected_exception_slot', name: declared)
    end
  end

  # `C019`: the address begins with `https://`, case indifferent, the assertion
  # lower-casing the value before comparing. Its context is the `rim:SlotValue`,
  # so a slot carrying no `rim:Value` breaks it too — `starts-with` of the empty
  # string is false.
  def insecure_preview_locations(found)
    all(found, "./rim:Slot[@name='#{PREVIEW_LOCATION}']/rim:SlotValue").filter_map do |value|
      declared = text_at(value, './rim:Value').to_s
      next if declared.downcase.start_with?(SECURE_SCHEME)

      violation('R-EDM-ERR-C019', 'preview_location_not_secure',
        location: named(declared, 'absent_value'), expected: SECURE_SCHEME)
    end
  end

  # `C022`, and the whole of what chapter 4.6 publishes under it: « If a
  # 'rim:Slot[@name='PreviewLocation']' is provided, the 'rs:Exception' MUST be
  # '…PreviewRequired' and use the rs:Exception xsi:type='rs:AuthorizationExceptionType'
  # (@code 'EDM:ERR:0002') ». Its assertion executes the first half alone.
  #
  # The phrase is what applies where the assertion merely under-executes it,
  # which is the case the Linear project « La conformité des messages reçus »
  # names — as opposed to an assertion that *contradicts* its own message, where
  # `docs/carte_des_tdd.md` has the assertion prevail. So the rule is named for
  # either half.
  #
  # The severity is looked for anywhere in the document, `//@severity` being
  # what the assertion writes and not the attribute of the exception carrying
  # the slot; the type is read on that exception, the sentence saying « the
  # rs:Exception ».
  def preview_without_authorisation(found)
    return [] if exception_slots(found, PREVIEW_LOCATION).empty?
    return [] if preview_severity_declared? && declared_attribute(found, 'xsi:type') == PREVIEW_TYPE

    [violation('R-EDM-ERR-C022', 'preview_without_authorisation',
      severity: EdmException::PREVIEW_REQUIRED, type: PREVIEW_TYPE)]
  end

  def preview_severity_declared?
    all(document, '//@severity').any? { |declared| declared.value == EdmException::PREVIEW_REQUIRED }
  end

  # `C020`, on the `@xml:lang` of every localised string of the description —
  # the namespaced attribute, where the `lang` of an `sdg:Name` carries none.
  # Its context is that attribute, so a string declaring no language breaks
  # nothing here.
  def preview_languages(found)
    path = "./rim:Slot[@name='#{PREVIEW_DESCRIPTION}']/rim:SlotValue/rim:Value/rim:LocalizedString"

    all(found, path).filter_map do |localised|
      language = attribute(localised, 'lang', 'xml')
      next if language.nil? || LanguageCode.valid?(language)

      violation('R-EDM-ERR-C020', 'preview_language_unknown', language:)
    end
  end

  # `C021` and `-S031`, published by the 1.2.5 Schematron alone: the slot 2.0
  # retired carries one of three HTTP verbs, and a report naming a preview
  # location on that line names the method to reach it with.
  def preview_method_violations(found)
    return [] unless specification.preview_method_slot?

    [*unexpected_preview_methods(found), preview_location_without_method(found)]
  end

  def unexpected_preview_methods(found)
    all(found, "./rim:Slot[@name='#{PREVIEW_METHOD}']/rim:SlotValue").filter_map do |value|
      declared = text_at(value, './rim:Value').to_s
      next if PREVIEW_METHODS.include?(declared)

      violation('R-EDM-ERR-C021', 'preview_method_unexpected',
        method: named(declared, 'absent_value'), expected: PREVIEW_METHODS.join(', '))
    end
  end

  def preview_location_without_method(found)
    return if exception_slots(found, PREVIEW_LOCATION).empty?
    return if exception_slots(found, PREVIEW_METHOD).any?

    violation('R-EDM-ERR-S031', 'preview_location_without_method')
  end

  # The other half of what chapter 4.5.3 §2 fixes and no FATAL assertion
  # executes: neither preview slot is ever doubled.
  def doubled_preview_slots(found)
    [PREVIEW_LOCATION, PREVIEW_DESCRIPTION].filter_map do |name|
      next if exception_slots(found, name).size <= 1

      violation(PREVIEW_SLOT_SINGLE, 'slot_doubled', name:)
    end
  end

  def exception_slots(found, name) = all(found, "./rim:Slot[@name='#{name}']")

  # The attributes of an exception, named as the rules name them: `xsi:type`
  # travels namespaced where the three others carry none.
  def declared_attribute(found, name)
    prefix, _, local = name.rpartition(':')

    prefix.empty? ? attribute(found, local) : attribute(found, local, prefix)
  end

  def reported_exceptions = declared_response ? all(declared_response, './rs:Exception') : []
end
