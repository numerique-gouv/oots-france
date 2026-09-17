# Reads the reference messages of `spec/fixtures/reference/`. See
# `spec/fixtures/README.md` for what each directory is worth as evidence:
# `reference/` and `incoming/reel/` are authoritative, `incoming/` is not.
module Fixtures
  def reference_message(name) = read_fixture("reference/messages/#{name}.xml")

  def reference_header(name) = read_fixture("reference/messages/#{name}.entete.xml")

  def reference_envelope(name) = read_fixture("reference/soap/#{name}.xml")

  def real_envelope(name) = read_fixture("incoming/reel/#{name}.xml")

  def built_envelope(name) = read_fixture("incoming/#{name}.xml")

  # A directory answer captured on the acceptance environment, with the two
  # headers that carry its signature.
  def common_services_answer(name)
    body = read_fixture("common_services/#{name}.xml")
    headers = read_fixture("common_services/#{name}.headers").lines.to_h do |line|
      field, value = line.split(':', 2)
      [field.strip.downcase, value.to_s.strip]
    end

    [body, headers]
  end

  # The captured Evidence Broker answer, its only list turned into the explicit
  # `NoMatch` of chapter 3.2.4: an empty `sdg:EvidenceTypeList` in a successful
  # answer, where a member state says it knows it issues nothing. Fabricated and
  # not captured, since no member state publishes one on the acceptance
  # environment — and the captures are signed over their bytes, so none of them
  # can be edited.
  #
  # `sdg:EvidenceType` sits between `sdg:Name` and `sdg:Jurisdiction`, which is
  # where the schema puts the two elements replacing it.
  def evidence_types_declaring_no_match(reason: nil)
    # Through a block: in a replacement string `sub` reads `\1` and `\&` as
    # backreferences, and the reason comes from the caller.
    common_services_answer('eb_evidence_types_fr').first
      .sub(%r{<sdg:EvidenceType>.*?</sdg:EvidenceType>}m) { no_match_declaration(reason:) }
  end

  # How a `NoMatch` is written on the wire, in one place: both fixtures below
  # replace the evidence type with it.
  def no_match_declaration(reason: nil)
    described = reason && %(<sdg:MatchDescription lang="EN">#{reason}</sdg:MatchDescription>)

    "<sdg:MatchType>#{EvidenceTypeList::NO_MATCH}</sdg:MatchType>#{described}"
  end

  # An Evidence Broker answer where several jurisdictions each publish several
  # evidence types, `{ 'AT' => 3, 'FR' => 2 }` giving Austria three and France
  # two. No capture holds one — `eb_evidence_types_fr`, `_deux_fr` and `_fi`
  # carry a single `sdg:EvidenceTypeList` each, so one country and one type —
  # and a capture is signed over its bytes, so this is built beside it rather
  # than by editing it (`spec/fixtures/README.md`, « Recapturer, jamais
  # retoucher »). Whoever serves it doubles the signature with
  # `stub_directory_signature`.
  #
  # What it is for: a page that adds up the weights of its cards cannot be told
  # apart from one that reports the last card's weight while every card weighs
  # the same, and a country code searched for as a word cannot be told from one
  # searched for anywhere in the text while the code begins its own name.
  def evidence_types_published_by(types_by_country)
    common_services_answer('eb_evidence_types_fr').first
      .sub(%r{<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>}m) do |published|
        types_by_country.map { |country, types| jurisdiction_publishing(published, country, types) }.join
      end
  end

  # The captured list, moved to another jurisdiction and given as many evidence
  # types as asked for.
  def jurisdiction_publishing(published, country, types)
    listed = Array.new(types) { |rank| evidence_type_numbered(published, country, rank) }.join

    published
      .sub(%r{<sdg:Identifier>[^<]*</sdg:Identifier>}) { "<sdg:Identifier>liste-#{country}</sdg:Identifier>" }
      .sub(%r{<sdg:EvidenceType>.*?</sdg:EvidenceType>}m) { listed }
      .sub(%r{<sdg:AdminUnitLevel1>[^<]*</sdg:AdminUnitLevel1>}) do
        "<sdg:AdminUnitLevel1>#{country}</sdg:AdminUnitLevel1>"
      end
  end

  # Each type carries a classification of its own, since
  # `EvidenceTypeList.distinct_evidence_types` deduplicates on `EvidenceType#id`
  # and a card announcing three would otherwise weigh one.
  #
  # The title names no country and carries no code: a card is searched by its
  # text, and a title holding « AT » would answer a search for the Austrian code
  # whether or not the code in brackets is read as a word — which is the very
  # thing a scenario here has to tell apart.
  def evidence_type_numbered(published, country, rank)
    classified = published[%r{<sdg:EvidenceType>.*?</sdg:EvidenceType>}m]
      .sub(%r{<sdg:EvidenceTypeClassification>[^<]*</sdg:EvidenceTypeClassification>}) do
        "<sdg:EvidenceTypeClassification>#{evidence_type_classification(country, rank)}" \
          '</sdg:EvidenceTypeClassification>'
      end

    classified.sub(%r{<sdg:Title lang="EN">[^<]*</sdg:Title>}) do
      %(<sdg:Title lang="EN">Dummy PDF #{rank + 1}</sdg:Title>)
    end
  end

  # Built on the host the capture names, the console addressing its own pages by
  # the last segment alone.
  def evidence_type_classification(country, rank)
    "https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/#{country}/" \
      "#{country.downcase}00000-0000-4000-8000-#{format('%012d', rank)}"
  end

  # The same declaration set beside a combination that does carry types: what a
  # member state publishes when it issues nothing under one jurisdiction and
  # something under another.
  def evidence_types_declaring_no_match_beside_types
    common_services_answer('eb_evidence_types_fr').first.sub(%r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m) do
      carrying = Regexp.last_match(1)

      carrying + carrying.sub(%r{<sdg:EvidenceType>.*?</sdg:EvidenceType>}m) { no_match_declaration }
    end
  end

  # A real envelope whose RegRep body has been altered — how a spec fabricates
  # a message that is well-formed for the gateway and wrong for the EDM. The
  # body travels base64-encoded inside the envelope, so it has to be decoded,
  # altered and encoded back.
  def envelope_with_body(name, &)
    document = Nokogiri::XML(real_envelope(name))
    rewrite_body(document, &)

    RetrievedMessageParser.new(document.to_xml)
  end

  # A real envelope carrying a RegRep body Nokogiri refuses, beside a payload it
  # reads perfectly: what proves that a document cost the line no field read off
  # the envelope itself.
  def envelope_with_unreadable_body
    document = Nokogiri::XML(real_envelope('reponseAvecPieceJointe'))
    document.xpath('//payload/value').first.content = Base64.strict_encode64('<query:QueryResponse')

    document.to_xml
  end

  # The slot a body announces its own version in — the half of the pair that
  # chapter 4.7 §2.6.2 calls « expressed in the payload », the other half being
  # the ebMS property of the header.
  SPECIFICATION_SLOT = %r{<rim:Slot name="SpecificationIdentifier">.*?</rim:Slot>}m

  # A real envelope whose two version announcements disagree: the header keeps
  # the line it was captured on, the body's slot claims the earlier one. The
  # message chapter 4.7 §2.6.2 holds invalid, and what a correspondent sends
  # when it announces one line in the envelope and writes the other in the
  # document.
  def envelope_announcing_two_specifications(name)
    envelope_with_body(name) { |body| body.sub(EdmSpecification::V2_0.identifier, EdmSpecification::V1_2.identifier) }
  end

  # The same envelope with the body's announcement taken out altogether: a value
  # that is not there expresses no identifier, so `R-EDM-RESP-S009` and
  # `R-EDM-ERR-S009` count it and no inconsistency is reported.
  def envelope_without_specification_slot(name) = envelope_with_body(name) { |body| body.sub(SPECIFICATION_SLOT, '') }

  # The same envelope as a correspondent of the 1.2 line would have sent it: the
  # header carries neither of the two properties only 2.0 knows —
  # `R-EDM-ebMS-037` names the exchange there and `-038` announces the version,
  # and 1.2.5 carries neither rule —, the body slot declares the older line, and
  # its `Procedure` slot takes the shape `R-EDM-REQ-S022` gives it there.
  #
  # Derived and not captured: no member state still on that line has been
  # reached, and stating the derivation is exactly stating what separates the two
  # lines. Removed by XPath rather than by a pattern, for the reason
  # `envelope_without` gives: the prefix a gateway binds to the ebMS namespace is
  # its own.
  #
  # **Every difference belongs here, and none may be left out for brevity.** A
  # fabrication that changed only some of them would be a document no
  # correspondent could send — and a test on a message that cannot exist proves
  # nothing about the ones that can. This is not hypothetical: while this
  # fabrication announced 1.2 and kept its `Procedure` slot in the 2.0 shape,
  # every example here passed green while France answered `EDM:ERR:0003` to
  # conformant 1.2 requests, and only the end-to-end suite saw it. Adding a
  # difference to `EdmSpecification` means adding it here in the same commit.
  def earlier_line_envelope(name = 'requete')
    document = Nokogiri::XML(real_envelope(name))
    document.xpath("//eb:Property[@name='SpecificationId'] | //eb:Property[@name='ExchangeId']",
      OotsNamespaces::NAMESPACES).each(&:remove)
    rewrite_body(document) do |body|
      downgraded = translated_procedure(body.sub(EdmSpecification::V2_0.identifier,
        EdmSpecification::V1_2.identifier))

      block_given? ? yield(downgraded) : downgraded
    end

    RetrievedMessageParser.new(document.to_xml)
  end

  # The captured response as the 1.2 line shapes it: the header of that line,
  # and a flat `rim:RegistryObjectList` — `R-EDM-RESP-S015` and `-S033` anchor on
  # the objects of the list itself there, where 2.0.1 moved them under a
  # `rim:RegistryPackageType`. The classification goes with the package: nothing
  # of that line names `MainEvidence`, one response carrying one document.
  def earlier_line_response(name = 'reponseAvecPieceJointe')
    earlier_line_envelope(name) do |body|
      flattened = flattened_registry_objects(body)

      block_given? ? yield(flattened) : flattened
    end
  end

  # `R-EDM-REQ-S022`: the `Procedure` slot of the 1.2 line is a
  # `rim:InternationalStringValueType`, the code sitting in the `@value` of a
  # `rim:LocalizedString` where 2.0 puts it in the text of the `rim:Value`.
  # Every literal space written `\s`: `/x` would otherwise drop the ones inside
  # the pattern, and the expression would match nothing at all.
  STRING_PROCEDURE = %r{(<rim:Slot\sname="Procedure">\s*<rim:SlotValue)\sxsi:type="rim:StringValueType">
                        \s*<rim:Value>([^<]*)</rim:Value>}x

  # The agent classified `ER` alone, whose name and identifier the rules of
  # chapter 4.6 judge and which France copies into what it signs. The
  # collection carries a second agent, classified `IP`, that a looser pattern
  # would reach instead — and the tempered `(?!</sdg:Agent>)` is what stops the
  # match at the first closing tag rather than swallowing both.
  REQUESTER_AGENT = %r{<sdg:Agent>(?:(?!</sdg:Agent>).)*<sdg:Classification>ER</sdg:Classification>\s*</sdg:Agent>}m

  # A real request whose requesting agent has been altered — the block receives
  # that agent alone, so nothing a spec writes can reach the platform beside it.
  def envelope_with_requester_agent(&) = envelope_with_body('requete') { |body| body.sub(REQUESTER_AGENT, &) }

  # Its counterpart: the agent that accompanies the requester in the same
  # collection, classified `IP` in the three requests the suite plays. The same
  # FATAL rules of chapter 4.6 judge it — none of their contexts naming a
  # classification — and France copies none of it into what it signs.
  PLATFORM_AGENT = %r{<sdg:Agent>(?:(?!</sdg:Agent>).)*<sdg:Classification>IP</sdg:Classification>\s*</sdg:Agent>}m

  def envelope_with_platform_agent(&) = envelope_with_body('requete') { |body| body.sub(PLATFORM_AGENT, &) }

  # The agent the `EvidenceProvider` slot carries — directly, that slot being an
  # `AnyValueType` where the requester travels in a collection of `rim:Element`.
  # What tells this agent from the two of the collection is where it sits and
  # not what it holds, hence the slot in the pattern; `\K` then drops everything
  # matched before the agent, so the block receives the agent alone, as the two
  # above do.
  PROVIDER_AGENT = %r{<rim:Slot name="EvidenceProvider">.*?\K<sdg:Agent>.*?</sdg:Agent>}m

  # A real request whose designated provider has been altered.
  def envelope_with_provider_agent(&) = envelope_with_body('requete') { |body| body.sub(PROVIDER_AGENT, &) }

  # The request the real envelope carries, about an organisation instead of the
  # person it names. `R-EDM-REQ-S016` admits one evidence subject and never two,
  # so the `NaturalPerson` slot gives way rather than being joined.
  #
  # Through a block: in a replacement string `sub` reads `\1` and `\&` as
  # backreferences, and the slot comes from the caller.
  #
  # The body is relabelled UTF-8, which the XML declaration says it is and
  # `Base64.decode64` cannot know: an organisation named with an accent would
  # otherwise meet a string Ruby holds as bytes.
  def envelope_about_an_organisation(subject = legal_person_slot)
    envelope_with_body('requete') do |body|
      body.dup.force_encoding(Encoding::UTF_8)
        .sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) { subject }
    end
  end

  # The `LegalPerson` slot of chapter 4.5.1, in the order `sdg:LegalPersonType`
  # imposes: the optional `Identifier` precedes the mandatory
  # `LegalPersonIdentifier`, the sequence being what the schema says it is.
  #
  # The company name carries an ampersand on purpose, so that the escaping
  # travels as far as the parser.
  def legal_person_slot
    <<~XML
      <rim:Slot name="LegalPerson">
        <rim:SlotValue xsi:type="rim:AnyValueType">
          <sdg:LegalPerson>
            <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
            <sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>
            <sdg:Identifier schemeID="LEI">969500HBOM1RJXTLZ57</sdg:Identifier>
            <sdg:LegalPersonIdentifier schemeID="eidas">FR/DE/A2635542Y</sdg:LegalPersonIdentifier>
            <sdg:LegalName>Établissements Dupont &amp; Fils</sdg:LegalName>
          </sdg:LegalPerson>
        </rim:SlotValue>
      </rim:Slot>
    XML
  end

  # The captured response, its subject turned into the organisation `sdg:IsAbout`
  # equally admits — the `xs:choice` forbidding the two to sit side by side.
  #
  # Through a block, and relabelled UTF-8, for the two reasons the request's
  # counterpart above gives.
  def response_about_an_organisation(subject = is_about_legal_person)
    envelope_with_body('reponseAvecPieceJointe') do |body|
      body.dup.force_encoding(Encoding::UTF_8).sub(%r{<sdg:NaturalPerson>.*?</sdg:NaturalPerson>}m) { subject }
    end
  end

  # What `R-EDM-RESP-S042` admits under `sdg:IsAbout`, and all of it — narrower
  # than the `legal_person_slot` a request carries, which is the point.
  def is_about_legal_person
    <<~XML
      <sdg:LegalPerson>
        <sdg:LegalPersonIdentifier schemeID="eidas">FR/DE/A2635542Y</sdg:LegalPersonIdentifier>
        <sdg:LegalName>Établissements Dupont &amp; Fils</sdg:LegalName>
      </sdg:LegalPerson>
    XML
  end

  # A real envelope with one of its elements taken out — how a spec fabricates a
  # message the gateway would have accepted and this application cannot read.
  # Through Nokogiri and not a regexp: the fixtures bind the ebMS namespace to
  # whatever prefix Domibus chose that day, so a pattern on the prefix silently
  # matches nothing.
  def envelope_without(name, xpath)
    document = Nokogiri::XML(real_envelope(name))
    document.xpath(xpath, OotsNamespaces::NAMESPACES).each(&:remove)

    RetrievedMessageParser.new(document.to_xml)
  end

  # The complement of the above: a real envelope with one of its elements given
  # another value — how a spec fabricates a message the gateway would have
  # accepted and a TDD rule refuses. Same binding by URI, for the same reason.
  def envelope_where(name, xpath, value)
    document = Nokogiri::XML(real_envelope(name))
    replace(document, xpath, value)

    RetrievedMessageParser.new(document.to_xml)
  end

  # Bang-free but still loud: `at_xpath` returns nil for a path that matches
  # nothing, and assigning to nil raises — where a substitution matching nothing
  # would leave the spec passing on an intact envelope.
  def replace(document, xpath, value)
    document.at_xpath(xpath, OotsNamespaces::NAMESPACES).content = value
  end

  private

  # Left alone where there is no such slot — a response carries none.
  def translated_procedure(body)
    body.sub(STRING_PROCEDURE) do
      %(#{Regexp.last_match(1)} xsi:type="rim:InternationalStringValueType">) +
        %(<rim:Value><rim:LocalizedString xml:lang="EN" value="#{Regexp.last_match(2)}"/></rim:Value>)
    end
  end

  # The package `R-EDM-RESP-S015` puts the objects under in 2.0.1, taken away
  # with the classification it exists to carry.
  def flattened_registry_objects(body)
    document = Nokogiri::XML(body)
    package = document.at_xpath('//rim:RegistryObjectList/rim:RegistryObject', SlotReading::NAMESPACES)
    objects = package.xpath('./rim:RegistryObjectList/rim:RegistryObject', SlotReading::NAMESPACES)
    objects.xpath('./rim:Classification', SlotReading::NAMESPACES).each(&:remove)
    package.replace(objects.map(&:to_xml).join)

    document.to_xml
  end

  def rewrite_body(document)
    value = document.at_xpath('//payload/value')
    value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))
  end

  def read_fixture(path) = Rails.root.join('spec/fixtures', path).read
end
