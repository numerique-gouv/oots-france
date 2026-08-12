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
    raise UnreadableMessageError, "Slot « #{name} » absent du message reçu." if found.nil?

    found
  end

  # A `rim:StringValueType`, `rim:DateTimeValueType`, `rim:BooleanValueType`…
  # anything whose content is a single `rim:Value`.
  def slot_text(name, scope)
    value = text_at(slot(name, scope), './rim:SlotValue/rim:Value')
    require_content(value, "Le slot « #{name} » est vide")
  end

  # A `rim:AnyValueType`: the tree under the slot value, whatever it is.
  def slot_content(name, scope, path)
    found = at(slot(name, scope), "./rim:SlotValue/#{path}")
    require_content(found, "Le slot « #{name} » ne porte pas #{path}")
  end

  # A `rim:CollectionValueType`: its `rim:Element` children, possibly none.
  def slot_elements(name, scope) = all(slot(name, scope), './rim:SlotValue/rim:Element')

  def require_content(value, description)
    raise UnreadableMessageError, "#{description} dans le message reçu." if value.nil? || value.to_s.strip.empty?

    value
  end
end
