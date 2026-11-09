# The requests of chapter 4.6 a spec judges, fabricated from the captured one,
# and what judges them: the parser, or one family of its rules built alone.
#
# Every helper goes through `received`, which reads the message as the parser
# does. The spec of a family overrides it with `judged`, so that the same
# altered request is judged by the family alone — the example reads the same,
# and only its target changes.
module ReceivedRequests
  def received(message) = message.body

  # The family the spec describes, built on the `query:QueryRequest` the
  # message carries and the version `RetrievedMessageParser` settles for it —
  # the two things `EvidenceRequestParser` hands each family. A family handed
  # more reads it from the request through the block.
  def judged(message)
    payload = Nokogiri::XML(message.raw).at_xpath('//payload/value')
    request = Nokogiri::XML(Base64.decode64(payload.text)).at_xpath('/query:QueryRequest', OotsNamespaces::NAMESPACES)

    described_class.new(request, specification: message.specification, **(block_given? ? yield(request) : {}))
  end

  # A `query:QueryRequest` written by hand and holding only what it is given:
  # what proves a family is judged without the request around it. Every
  # namespace the messages use is bound, so a fragment needs declare none.
  def query_request(content)
    bound = OotsNamespaces::NAMESPACES.except('xml').map { |prefix, uri| %( xmlns:#{prefix}="#{uri}") }.join

    Nokogiri::XML("<query:QueryRequest#{bound}>#{content}</query:QueryRequest>").root
  end

  # The body travels base64-encoded inside the envelope, so a fixture cannot be
  # edited in place: it has to be decoded, altered, and encoded back. Editing
  # the envelope string directly changes nothing at all — silently.
  def with_body
    envelope = real_envelope('requete')
    document = Nokogiri::XML(envelope)
    value = document.xpath('//payload/value').first
    value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))

    received(RetrievedMessageParser.new(document.to_xml))
  end

  # What a rule of chapter 4.6 refuses, said once: the identifier travels in the
  # `detail` of the failure, which is what reaches the `EDM:ERR:0003` and the
  # journal alike.
  def refusing(rule)
    raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: rule)))
  end

  # The agent classified `ER` alone, `Fixtures::REQUESTER_AGENT` saying why.
  def with_requester_agent(&) = received(envelope_with_requester_agent(&))

  # `nil` removes the attribute, where an empty string writes it blank:
  # `R-EDM-REQ-C011` asserts its presence and `C012` judges its value.
  def with_requester_scheme(scheme) = with_requester_agent { |agent| replace_scheme(agent, scheme) }

  def with_requester_id(id) = with_requester_agent { |agent| replace_id(agent, id) }

  def without_requester_identifier = with_requester_agent { |agent| remove_identifier(agent) }

  # The slot itself, and not the agent it carries: `R-EDM-REQ-S012` counts it
  # among the children of `query:QueryRequest`, `R-EDM-REQ-S015` its counterpart
  # `EvidenceRequest` among those of `query:Query`.
  def without_requester_slot = without_slot('EvidenceRequester')

  # The slot as `R-EDM-REQ-S028`, `S029`, `S052` and `S053` require it — a
  # collection, declaring its type, carrying an element — and carrying no
  # `sdg:Agent`: what `S039` alone refuses.
  def without_any_agent
    with_body do |body|
      body.sub(slot('EvidenceRequester')) do
        '<rim:Slot name="EvidenceRequester"><rim:SlotValue xsi:type="rim:CollectionValueType" ' \
          'collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">' \
          '<rim:Element xsi:type="rim:AnyValueType"/></rim:SlotValue></rim:Slot>'
      end
    end
  end

  def with_doubled_requester_slot = with_doubled_slot('EvidenceRequester')

  def without_evidence_request = without_slot('EvidenceRequest')

  def with_doubled_evidence_request = with_doubled_slot('EvidenceRequest')

  # Both halves of a rule that counts, written once: `spec/parsers/evidence_response_parser_spec.rb`
  # cuts its own slots out the same way.
  def slot(name) = %r{<rim:Slot name="#{name}">.*?</rim:Slot>}m

  def without_slot(name) = with_body { |body| body.sub(slot(name), '') }

  def with_doubled_slot(name) = with_body { |body| body.sub(slot(name)) { |found| found * 2 } }

  def with_requester_name(name) = with_requester_agent { |agent| replace_name(agent, name) }

  def with_second_requester_name(second) = with_requester_agent { |agent| add_name(agent, second) }

  def with_requester_language(value) = with_requester_agent { |agent| replace_language(agent, value) }

  def with_requester_country(code)
    with_requester_agent do |agent|
      agent.sub(/(<sdg:AdminUnitLevel1>)[^<]*/) { "#{Regexp.last_match(1)}#{code}" }
    end
  end

  # `AddressType` puts `AdminUnitLevel2` after `AdminUnitLevel1`, and the real
  # request carries no such element: it is added rather than substituted.
  def with_requester_territory(code)
    with_requester_agent do |agent|
      agent.sub(%r{(</sdg:AdminUnitLevel1>)}) { "#{Regexp.last_match(1)}<sdg:AdminUnitLevel2>#{code}</sdg:AdminUnitLevel2>" }
    end
  end

  # The real request names no identifier for its beneficiary, so one is added
  # here. Its value is of the shape `R-EDM-REQ-C040` fixes, that rule being a
  # different one from the two under test.
  def with_beneficiary_identifier(attributes)
    identifier = "<sdg:Identifier#{attributes}>FR/DE/A2635542Y</sdg:Identifier>"
    identifier = yield(identifier) if block_given?

    with_body { |body| body.sub('</sdg:LevelOfAssurance>', "</sdg:LevelOfAssurance>#{identifier}") }
  end

  # An element added under an agent, after its `sdg:Name`: what
  # `R-EDM-REQ-S040` and `S043` count as one child too many.
  # Through a block, and `sub` on a literal rather than on a pattern: in a
  # replacement string `sub` reads `\1` and `\&` as backreferences, and the
  # element comes from the caller.
  def agent_carrying(agent, element) = agent.sub('</sdg:Name>') { "</sdg:Name>#{element}" }

  # The agent beside the requester alone, `Fixtures::PLATFORM_AGENT` saying why.
  def with_platform_agent(&) = received(envelope_with_platform_agent(&))

  # `nil` removes the element rather than emptying it: `R-EDM-REQ-C013`
  # normalises, so the two must be told apart by what is written.
  def with_platform_classification(value)
    with_platform_agent do |agent|
      agent.sub(%r{<sdg:Classification>[^<]*</sdg:Classification>},
        value.nil? ? '' : "<sdg:Classification>#{value}</sdg:Classification>")
    end
  end

  # `nil` removes the attribute, where an empty string writes it blank:
  # `R-EDM-REQ-C011` asserts its presence and `C012` judges its value.
  def with_platform_scheme(scheme) = with_platform_agent { |agent| replace_scheme(agent, scheme) }

  def with_platform_id(id) = with_platform_agent { |agent| replace_id(agent, id) }

  def without_platform_identifier = with_platform_agent { |agent| remove_identifier(agent) }

  def with_platform_name(name) = with_platform_agent { |agent| replace_name(agent, name) }

  def without_platform_name = with_platform_agent { |agent| remove_name(agent) }

  def with_second_platform_name(second) = with_platform_agent { |agent| add_name(agent, second) }

  def with_platform_language(value) = with_platform_agent { |agent| replace_language(agent, value) }

  # The platform of the real request declares no address, `R-EDM-REQ-C073`
  # requiring one of the agent classified `ER` alone: this one is added where
  # `AgentType` puts it, between the name and the classification.
  def with_platform_address(address)
    with_platform_agent do |agent|
      agent.sub(%r{(<sdg:Name[^>]*>[^<]*</sdg:Name>)}) { "#{Regexp.last_match(1)}#{address}" }
    end
  end

  def with_platform_country(code)
    with_platform_address("<sdg:Address><sdg:AdminUnitLevel1>#{code}</sdg:AdminUnitLevel1></sdg:Address>")
  end

  # The country beside it, `AddressType` sequencing the two: a territory alone
  # would be judged all the same — `C016`'s context is its own element — but an
  # address shaped as the schema shapes it is what a correspondent sends.
  def with_platform_territory(code)
    with_platform_address(
      "<sdg:Address><sdg:AdminUnitLevel1>DE</sdg:AdminUnitLevel1><sdg:AdminUnitLevel2>#{code}</sdg:AdminUnitLevel2></sdg:Address>"
    )
  end

  # The agent of the `EvidenceProvider` slot alone, `Fixtures::PROVIDER_AGENT`
  # saying why it is reached through its slot.
  def with_provider_agent(&) = received(envelope_with_provider_agent(&))

  def without_provider_agent = with_provider_agent { '' }

  def with_provider_scheme(scheme) = with_provider_agent { |agent| replace_scheme(agent, scheme) }

  def with_provider_id(id) = with_provider_agent { |agent| replace_id(agent, id) }

  def without_provider_identifier = with_provider_agent { |agent| remove_identifier(agent) }

  def with_provider_name(name) = with_provider_agent { |agent| replace_name(agent, name) }

  def without_provider_name = with_provider_agent { |agent| remove_name(agent) }

  def with_second_provider_name(second) = with_provider_agent { |agent| add_name(agent, second) }

  def with_provider_language(value) = with_provider_agent { |agent| replace_language(agent, value) }

  # A second `sdg:Agent` under the same slot value, beside the one the request
  # designates. The block, where a spec passes one, alters the **first** agent,
  # so that what the reader designates can be told from what it merely judges.
  def beside_the_provider(**)
    with_provider_agent { |agent| (block_given? ? yield(agent) : agent) + second_provider_agent(**) }
  end

  # Conformant to the four rules that reach it by default, so that each example
  # breaks the one it names and no other.
  def second_provider_agent(identifier: %(<sdg:Identifier schemeID="#{IdentifierScheme::EAS_PREFIX}0009">AUTRE</sdg:Identifier>),
                            name: '<sdg:Name lang="EN">Another provider</sdg:Name>', classification: '')
    "<sdg:Agent>#{identifier}#{name}#{classification}</sdg:Agent>"
  end

  # A third agent in the collection, beside the two the real request carries:
  # what proves the walk judges each of the agents the requester is not, and
  # not the first of them.
  def with_third_agent(agent)
    with_body do |body|
      body.sub(%r{(<rim:Slot name="EvidenceRequester">.*?)(</rim:SlotValue>)}m) do
        "#{Regexp.last_match(1)}<rim:Element xsi:type=\"rim:AnyValueType\">#{agent}</rim:Element>#{Regexp.last_match(2)}"
      end
    end
  end

  # The substitutions the three agents take, written once: only the agent they
  # are applied to differs.
  def replace_id(agent, id) = agent.sub(/(<sdg:Identifier[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{id}" }

  def remove_identifier(agent) = agent.sub(%r{<sdg:Identifier[^>]*>[^<]*</sdg:Identifier>}, '')

  def replace_name(agent, name) = agent.sub(/(<sdg:Name[^>]*>)[^<]*/) { "#{Regexp.last_match(1)}#{name}" }

  def remove_name(agent) = agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}, '')

  def add_name(agent, second) = agent.sub(%r{<sdg:Name[^>]*>[^<]*</sdg:Name>}) { |first| "#{first}#{second}" }

  # `nil` removes the attribute rather than writing it blank: `R-EDM-REQ-C011`
  # and `C017` assert its presence, `C012` and `C018` judge its value.
  def replace_scheme(agent, scheme)
    agent.sub(/ schemeID="[^"]*"/, scheme.nil? ? '' : %( schemeID="#{scheme}"))
  end

  # `nil` removes the attribute rather than emptying it: `R-EDM-REQ-C109`
  # normalises, so the two must be told apart by what is written and not by
  # what is read.
  def replace_language(agent, value)
    agent.sub(/<sdg:Name lang="[^"]*">/, value.nil? ? '<sdg:Name>' : %(<sdg:Name lang="#{value}">))
  end

  # The real request carries no such slot, so the specs write one. Its shape
  # is that of the example published with chapter 4.5.1 — « 3.4 Evidence
  # Provider Classification slot and example » — rather than one invented
  # here: a version 4 UUID under a Semantic Repository scheme, the type
  # `codelist`, an `https://` value expression, a description naming its
  # language, and one supported value carrying a `sdg:StringValue`, in the
  # order `InformationConceptType` sequences them.
  #
  # `nil` takes an element or an attribute away where an empty string writes
  # it blank: several of the rules below tell the two apart.
  def classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Lau2022',
                     id: '5ce148b9-5578-4049-aecf-af7bb55714b5', type: 'codelist',
                     expression: value_expression,
                     descriptions: '<sdg:Description lang="EN">Select the city in which you were born.</sdg:Description>',
                     values: '<sdg:SupportedValue><sdg:StringValue>11000000</sdg:StringValue></sdg:SupportedValue>')
    <<~XML
      <sdg:EvidenceProviderClassification>
        <sdg:Identifier#{scheme && %( schemeID="#{scheme}")}>#{id}</sdg:Identifier>
        #{type && "<sdg:Type>#{type}</sdg:Type>"}
        #{expression && "<sdg:ValueExpression>#{expression}</sdg:ValueExpression>"}
        #{descriptions}
        #{values}
      </sdg:EvidenceProviderClassification>
    XML
  end

  # The URL of the published example, its hash cut short: what
  # `R-EDM-REQ-C101` reads is the scheme it starts with and nothing else.
  def value_expression = 'https://query.cs.uat.oots.tech.ec.europa.eu/dsd/rest/codelists/DE/Lau2022/a591a6d4'

  # Les deux types sont paramétrables parce que `R-EDM-REQ-S031` et `S032` les
  # fixent : le slot est une collection, chacun de ses `rim:Element` une valeur
  # quelconque. Les valeurs par défaut sont celles que les règles demandent, et
  # tous les exemples de ce bloc les prennent — les deux qui en changent
  # prouvent que la règle refuse le reste.
  def classification_slot(*elements, type: 'rim:CollectionValueType', element_type: 'rim:AnyValueType')
    collection = elements.map { |element| %(<rim:Element xsi:type="#{element_type}">#{element}</rim:Element>) }

    <<~XML
      <rim:Slot name="EvidenceProviderClassification">
        <rim:SlotValue xsi:type="#{type}"
                       collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
          #{collection.join}
        </rim:SlotValue>
      </rim:Slot>
      <rim:Slot name="EvidenceRequester">
    XML
  end

  # Through a block: in a replacement string `sub` reads `\1` and `\&` as
  # backreferences, and the slot comes from the caller.
  def with_classifications(*elements, **)
    with_body { |body| body.sub('<rim:Slot name="EvidenceRequester">') { classification_slot(*elements, **) } }
  end
end
