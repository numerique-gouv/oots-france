# Reads the RegRep slots the OOTS messages are made of: a `rim:SlotValue`
# whose `xsi:type` says how to read it — a plain value, a collection of
# elements, or an arbitrary tree.
#
# A missing slot raises rather than returning nil, which would surface much
# later as a message addressed to nobody; unreadable requests are answered with
# `EDM:ERR:0003`.
module SlotReading
  include OotsNamespaces

  private

  def slot(name, scope)
    found = at(scope, "./rim:Slot[@name='#{name}']")
    raise UnreadableMessageError, I18n.t('parsers.slot_reading.missing', name:) if found.nil?

    found
  end

  # A `rim:StringValueType`, `rim:DateTimeValueType`, `rim:BooleanValueType`…
  # anything whose content is a single `rim:Value`.
  def slot_text(name, scope)
    value = text_at(slot(name, scope), './rim:SlotValue/rim:Value')
    require_content(value, 'parsers.slot_reading.empty', name:)
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
