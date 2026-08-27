# Reads the RegRep slots the OOTS messages are made of: a `rim:SlotValue`
# whose `xsi:type` says how to read it — a plain value, a collection of
# elements, or an arbitrary tree.
#
# A missing slot raises rather than returning nil, which would surface much
# later as a message addressed to nobody; unreadable requests are answered with
# `EDM:ERR:0003`. That holds for the slots a rule requires, which is nearly all
# of them — `optional_slot_text` carries the exception.
module SlotReading
  include OotsNamespaces

  private

  def slot(name, scope)
    found = find_slot(name, scope)
    raise UnreadableMessageError, I18n.t('parsers.slot_reading.missing', name:) if found.nil?

    found
  end

  def find_slot(name, scope) = at(scope, "./rim:Slot[@name='#{name}']")

  # A `rim:StringValueType`, `rim:DateTimeValueType`, `rim:BooleanValueType`…
  # anything whose content is a single `rim:Value`.
  def slot_text(name, scope) = slot_value(slot(name, scope), name)

  def slot_value(found, name)
    require_content(text_at(found, './rim:SlotValue/rim:Value'), 'parsers.slot_reading.empty', name:)
  end

  # A slot the message is allowed not to carry, where absence is an answer and
  # not a failure: `R-EDM-ERR-C022` attaches `PreviewLocation` to one severity
  # and to no other, so every ordinary error legitimately omits it. Read through
  # `slot_text` instead, its absence would be reported as an unreadable field on
  # the majority of arrivals, and the warnings that say a message really was
  # malformed would be lost in them.
  #
  # A slot that is present and empty still raises: that one is malformed.
  def optional_slot_text(name, scope)
    found = find_slot(name, scope)
    return if found.nil?

    slot_value(found, name)
  end

  # A `rim:AnyValueType`: the tree under the slot value, whatever it is.
  def slot_content(name, scope, path)
    found = at(slot(name, scope), "./rim:SlotValue/#{path}")
    require_content(found, 'parsers.slot_reading.without', name:, path:)
  end

  # A `rim:CollectionValueType`: its `rim:Element` children, possibly none.
  def slot_elements(name, scope) = all(slot(name, scope), './rim:SlotValue/rim:Element')

  # The country an agent declares, under the address that `R-EDM-REQ-C073` and
  # its response and error counterparts impose on it — the only thing they
  # impose there.
  #
  # Upcased, and kept only if it is shaped like a country code: a correspondent
  # writing `fr` would otherwise be stored as written, and never match a filter,
  # which upcases what it is asked. What is not a code at all is dropped rather
  # than stored unusable — the journal keeps what it could read.
  def agent_country(agent)
    code = text_at(agent, './sdg:Address/sdg:AdminUnitLevel1').to_s.upcase

    code if code.match?(/\A[A-Z]{2}\z/)
  end

  # The description travels as a key: what is missing is named by the parser
  # that looked for it, and where it was looked for is the same sentence for all.
  def require_content(value, key, **)
    return value unless value.nil? || value.to_s.strip.empty?

    raise UnreadableMessageError,
      I18n.t('parsers.slot_reading.in_received_message', description: I18n.t(key, **))
  end
end
