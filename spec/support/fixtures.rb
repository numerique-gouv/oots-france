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
  def envelope_with_body(name)
    document = Nokogiri::XML(real_envelope(name))
    value = document.xpath('//payload/value').first
    value.content = Base64.strict_encode64(yield(Base64.decode64(value.text)))

    RetrievedMessageParser.new(document.to_xml)
  end

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

  def read_fixture(path) = Rails.root.join('spec/fixtures', path).read
end
