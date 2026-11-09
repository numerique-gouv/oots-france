require 'rails_helper'

RSpec.describe RegRepShapeConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to the slots the family judges' do
    def reduced(type)
      slot = %(<rim:Slot name="IssueDateTime"><rim:SlotValue xsi:type="#{type}">) \
             '<rim:Value>2026-09-14T10:00:00Z</rim:Value></rim:SlotValue></rim:Slot>'

      described_class.new(query_request("#{slot}<query:Query/>"), specification: EdmSpecification::V2_0)
    end

    it 'accepts a slot declaring the type its rule asks for' do
      expect(reduced('rim:DateTimeValueType').validate!).to be_a(described_class)
    end

    it 'refuses one declaring another, under the rule that types it' do
      expect { reduced('rim:StringValueType').validate! }
        .to refusing(described_class::QUERY_REQUEST_SLOT_TYPES.fetch('IssueDateTime').fetch(:rule))
    end
  end

  # Chapter 4.6 on the RegRep shape of the slots: nineteen FATAL rules, all of
  # one form — `substring-after(@xsi:type, ':')` compared to a single local
  # name. The prefix is therefore not judged, and the context is the
  # `rim:SlotValue` of a slot that is there, its presence being counted by the
  # rules `REQUIRED_SLOTS` carries.
  describe 'the RegRep type the slots declare' do
    # `nil` takes the attribute away, where a value replaces it. `bound` binds
    # the prefix `x` on the element itself, so that a document naming a type
    # under an unusual prefix still parses.
    def slot_typed(name, type, bound: nil)
      declared = type.nil? ? '' : %( xsi:type="#{type}")
      declared += %( xmlns:x="#{bound}") if bound

      with_body { |body| body.sub(slot(name)) { |found| found.sub(/ xsi:type="[^"]*"/, declared) } }
    end

    def element_typed(name, type)
      with_body do |body|
        body.sub(slot(name)) { |found| found.sub(/<rim:Element xsi:type="[^"]*"/, %(<rim:Element xsi:type="#{type}")) }
      end
    end

    it 'accepts the types the real request declares' do
      expect(request.validate!).to be(request)
    end

    it 'refuses an EvidenceProvider slot declared a collection, under R-EDM-REQ-S030' do
      expect { slot_typed('EvidenceProvider', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S030')
    end

    it 'refuses a Requirements slot declared an any value, under R-EDM-REQ-S026' do
      expect { slot_typed('Requirements', 'rim:AnyValueType').validate! }.to refusing('R-EDM-REQ-S026')
    end

    it 'refuses a collection element declared a collection, under R-EDM-REQ-S027' do
      expect { element_typed('Requirements', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S027')
    end

    # The slots of `query:Query` are typed by rules of their own, and the walk
    # reads them under that element rather than under the request.
    it 'refuses a NaturalPerson slot declared a collection, under R-EDM-REQ-S035' do
      expect { slot_typed('NaturalPerson', 'rim:CollectionValueType').validate! }.to refusing('R-EDM-REQ-S035')
    end

    # `substring-after` yields the empty string when the separator is missing,
    # and an absent attribute leaves nothing to search at all: neither matches
    # the name the rule asks for.
    it 'refuses a slot value declaring no type at all, under R-EDM-REQ-S020' do
      expect { slot_typed('SpecificationIdentifier', nil).validate! }.to refusing('R-EDM-REQ-S020')
    end

    it 'refuses a type written without a prefix, which the rule reads as empty' do
      expect { slot_typed('EvidenceProvider', 'AnyValueType').validate! }.to refusing('R-EDM-REQ-S030')
    end

    # The rule compares what follows the colon and nothing else, so a prefix
    # bound to anything at all satisfies it. Refusing this would refuse what a
    # FATAL rule admits, which is the mistake this whole reading exists to
    # avoid.
    it 'accepts a type under a prefix bound to something other than rim' do
      served = slot_typed('EvidenceProvider', 'x:AnyValueType', bound: OotsNamespaces::NAMESPACES.fetch('sdg'))

      expect(served.validate!).to be(served)
    end

    # Une ligne de table jamais exercée est une transcription jamais vérifiée,
    # et transcrire est tout ce que ces trois tables font. Chaque ligne a donc
    # son exemple, sous l'identifiant que la règle porte dans le Schematron —
    # écrit ici à la main, jamais lu dans la table, sans quoi une ligne écrite à
    # l'envers se vérifierait elle-même. Le type accepté, lui, est prouvé par
    # l'exemple d'ouverture, que la requête réelle satisfait.
    {
      'SpecificationIdentifier' => %w[rim:BooleanValueType R-EDM-REQ-S020],
      'IssueDateTime' => %w[rim:StringValueType R-EDM-REQ-S021],
      'Procedure' => %w[rim:BooleanValueType R-EDM-REQ-S022],
      'PossibilityForPreview' => %w[rim:StringValueType R-EDM-REQ-S024],
      'ExplicitRequestGiven' => %w[rim:StringValueType R-EDM-REQ-S025],
      'Requirements' => %w[rim:AnyValueType R-EDM-REQ-S026],
      'EvidenceRequester' => %w[rim:AnyValueType R-EDM-REQ-S028],
      'EvidenceProvider' => %w[rim:CollectionValueType R-EDM-REQ-S030],
    }.each do |name, (wrong, rule)|
      it "refuses a #{name} slot declared #{wrong}, under #{rule}" do
        expect { slot_typed(name, wrong).validate! }.to refusing(rule)
      end
    end

    { 'NaturalPerson' => 'R-EDM-REQ-S035', 'EvidenceRequest' => 'R-EDM-REQ-S033' }.each do |name, rule|
      it "refuses a #{name} slot of query:Query declared a collection, under #{rule}" do
        expect { slot_typed(name, 'rim:CollectionValueType').validate! }.to refusing(rule)
      end
    end

    { 'Requirements' => 'R-EDM-REQ-S027', 'EvidenceRequester' => 'R-EDM-REQ-S029' }.each do |name, rule|
      it "refuses a rim:Element of #{name} declared a collection, under #{rule}" do
        expect { element_typed(name, 'rim:CollectionValueType').validate! }.to refusing(rule)
      end
    end

    # Les quatre slots que la requête réelle ne porte pas. Chacun a besoin de ses
    # deux moitiés : le refus prouve que la règle est appliquée sous le bon
    # identifiant, l'acceptation que le type attendu est celui que la règle
    # demande — un refus seul passerait quel que soit le type inscrit dans la
    # table.
    describe 'the slots the real request does not carry' do
      # Écrits avant d'être jugés : le contexte de chaque règle est le
      # `rim:SlotValue` d'un slot présent, donc un slot absent ne déclenche rien.
      # L'ancre dit sous quel élément il se pose — `query:QueryRequest` pour les
      # deux premiers, `query:Query` pour les deux derniers.
      # `R-EDM-REQ-S062` pairs the two addresses of chapter 4.9, so each is
      # written beside a well-typed other half.
      PAIRED = {
        'PreviewLocation' => 'ReturnLocation', 'ReturnLocation' => 'PreviewLocation',
      }.freeze

      def slot_written(name, type, content, before: '<rim:Slot name="EvidenceRequester">')
        written = %(<rim:Slot name="#{name}"><rim:SlotValue xsi:type="#{type}">#{content}</rim:SlotValue></rim:Slot>)
        written = "#{string_slot(PAIRED[name], 'https://example.si/autre')}#{written}" if PAIRED.key?(name)

        with_body { |body| body.sub(before) { "#{written}#{before}" } }
      end

      {
        'PreviewLocation' => ['R-EDM-REQ-S023', 'rim:StringValueType',
                              '<rim:Value>https://example.si/apercu</rim:Value>',
                              '<rim:Slot name="EvidenceRequester">'],
        'ReturnLocation' => ['R-EDM-REQ-S061', 'rim:StringValueType',
                             '<rim:Value>https://example.si/retour</rim:Value>',
                             '<rim:Slot name="EvidenceRequester">'],
        # Conformant representatives, and not the bare names a slot type needs:
        # `R-EDM-REQ-C058` asks the one for a level of assurance, and `C082` and
        # `C084` ask the other for that and for its identifier, so a sketch
        # would be refused on its content before its type was ever judged.
        'AuthorizedRepresentative' => ['R-EDM-REQ-S036', 'rim:AnyValueType',
                                       '<sdg:Person><sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                                       '<sdg:FamilyName>Novak</sdg:FamilyName></sdg:Person>',
                                       '<rim:Slot name="NaturalPerson">'],
        'AuthorizedRepresentativeLegalPerson' => ['R-EDM-REQ-S055', 'rim:AnyValueType',
                                                  '<sdg:LegalPerson><sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                                                  '<sdg:LegalPersonIdentifier schemeID="eidas">SI/SI/123456' \
                                                  '</sdg:LegalPersonIdentifier>' \
                                                  '<sdg:LegalName>Novak d.o.o.</sdg:LegalName></sdg:LegalPerson>',
                                                  '<rim:Slot name="NaturalPerson">'],
      }.each do |name, (rule, expected, content, before)|
        it "accepts a #{name} slot declared #{expected}" do
          written = slot_written(name, expected, content, before:)

          expect(written.validate!).to be(written)
        end

        it "refuses one declared a collection, under #{rule}" do
          written = slot_written(name, 'rim:CollectionValueType', content, before:)

          expect { written.validate! }.to refusing(rule)
        end
      end
    end
  end

  # `R-EDM-REQ-S019`, `S049` and `S045` close three lists of names: the slots
  # `query:QueryRequest` may carry, those `query:Query` may, and the elements an
  # evidence type may. A slot outside them was served until now, its type table
  # simply passing it over.
  describe 'the names each level admits' do
    it 'refuses a slot of query:QueryRequest that no rule names, under R-EDM-REQ-S019' do
      invented = with_body do |body|
        body.sub('<rim:Slot name="EvidenceRequester">') do
          '<rim:Slot name="Foo"><rim:SlotValue xsi:type="rim:StringValueType">' \
            '<rim:Value>x</rim:Value></rim:SlotValue></rim:Slot><rim:Slot name="EvidenceRequester">'
        end
      end

      expect { invented.validate! }.to refusing('R-EDM-REQ-S019')
    end

    it 'refuses a slot of query:Query that no rule names, under R-EDM-REQ-S049' do
      invented = with_body do |body|
        body.sub('<rim:Slot name="EvidenceRequest">') do
          '<rim:Slot name="Foo"><rim:SlotValue xsi:type="rim:AnyValueType">' \
            '<sdg:Person/></rim:SlotValue></rim:Slot><rim:Slot name="EvidenceRequest">'
        end
      end

      expect { invented.validate! }.to refusing('R-EDM-REQ-S049')
    end

    # The rule counts the children it names against the total, so anything else
    # breaks it — including what the schema itself admits there, `sdg:Note` and
    # `sdg:AccessService` among them. The `.sch` is what plays where the two
    # disagree, and `docs/carte_des_tdd.md` records the disagreement.
    it 'refuses an evidence type carrying an element it does not name, under R-EDM-REQ-S045' do
      noted = with_body do |body|
        body.sub('</sdg:DataServiceEvidenceType>') { '<sdg:Note>Rien</sdg:Note></sdg:DataServiceEvidenceType>' }
      end

      expect { noted.validate! }.to refusing('R-EDM-REQ-S045')
    end

    # Counted and not tested name by name, which is what makes this fail: the
    # child has an admitted local name and the wrong namespace, so it adds to the
    # total of the children and to none of the five counts.
    it 'refuses one whose extra child only borrows an admitted local name' do
      borrowed = with_body do |body|
        body.sub('</sdg:DataServiceEvidenceType>') do
          '<x:Title xmlns:x="urn:example:x">Emprunt</x:Title></sdg:DataServiceEvidenceType>'
        end
      end

      expect { borrowed.validate! }.to refusing('R-EDM-REQ-S045')
    end
  end

  # `R-EDM-REQ-S050` and `S051`, whose contexts are a bare `rim:Slot` and a bare
  # `rim:SlotValue`: no ancestor narrows either, so both reach the slots of
  # `query:Query` as much as those of the request. The readers fetched the slot
  # value they wanted and never counted them.
  describe 'the slot values every slot carries' do
    it 'refuses a slot carrying no rim:SlotValue, under R-EDM-REQ-S050' do
      emptied = with_body { |body| body.sub(%r{(<rim:Slot name="Procedure">).*?(</rim:Slot>)}m, '\\1\\2') }

      expect { emptied.validate! }.to refusing('R-EDM-REQ-S050')
    end

    # `= 1` and not `>= 1`, as the assertion has it: two values leave which one
    # is meant undecided.
    it 'refuses a slot carrying two of them, under the same rule' do
      doubled = with_body do |body|
        body.sub(%r{<rim:Slot name="Procedure">(.*?)</rim:Slot>}m) do
          "<rim:Slot name=\"Procedure\">#{Regexp.last_match(1)}#{Regexp.last_match(1)}</rim:Slot>"
        end
      end

      expect { doubled.validate! }.to refusing('R-EDM-REQ-S050')
    end

    it 'refuses a rim:SlotValue carrying no element at all, under R-EDM-REQ-S051' do
      hollow = with_body do |body|
        body.sub(%r{(<rim:Slot name="Procedure">\s*<rim:SlotValue[^>]*>).*?(</rim:SlotValue>)}m, '\\1\\2')
      end

      expect { hollow.validate! }.to refusing('R-EDM-REQ-S051')
    end
  end

  # `R-EDM-REQ-S044`, `S046`, `S047`, `S048` and `S056`: the `sdg:` element each
  # slot of `query:Query` puts under its value. The readers refused these
  # absences already, through `SlotReading#slot_content`, but naming no rule —
  # so the correspondent got an `EDM:ERR:0003` with an empty `detail`.
  describe 'the element each slot of the query carries' do
    # The two the reference request already carries, emptied of their element.
    {
      'R-EDM-REQ-S044' => ['EvidenceRequest', 'sdg:DataServiceEvidenceType'],
      'R-EDM-REQ-S046' => ['NaturalPerson', 'sdg:Person'],
    }.each do |rule, (name, element)|
      it "refuses a #{name} slot value carrying no #{element}, under #{rule}" do
        stripped = with_body do |body|
          body.sub(%r{(<rim:Slot name="#{name}">\s*<rim:SlotValue[^>]*>).*?(</rim:SlotValue>)}m) do
            "#{Regexp.last_match(1)}<sdg:Autre/>#{Regexp.last_match(2)}"
          end
        end

        expect { stripped.validate! }.to refusing(rule)
      end
    end

    # And the three it does not, written in carrying the wrong element. The
    # people rules never fire on these: they look for an `sdg:Person` or an
    # `sdg:LegalPerson` that is precisely what is missing, so the refusal that
    # comes back is the slot-content one and not a value rule standing in for it.
    def hollow_slot(name)
      "<rim:Slot name=\"#{name}\"><rim:SlotValue xsi:type=\"rim:AnyValueType\"><sdg:Autre/></rim:SlotValue></rim:Slot>"
    end

    {
      'R-EDM-REQ-S048' => ['AuthorizedRepresentative', 'sdg:Person'],
      'R-EDM-REQ-S056' => ['AuthorizedRepresentativeLegalPerson', 'sdg:LegalPerson'],
    }.each do |rule, (name, element)|
      it "refuses a #{name} slot value carrying no #{element}, under #{rule}" do
        stripped = with_body do |body|
          body.sub('<rim:Slot name="NaturalPerson">') { "#{hollow_slot(name)}<rim:Slot name=\"NaturalPerson\">" }
        end

        expect { stripped.validate! }.to refusing(rule)
      end
    end

    # The subject slot is replaced and not doubled: `R-EDM-REQ-S016` counts the
    # two subject slots and refuses a request naming both, so adding one beside
    # the other would be refused under that rule and prove nothing about this one.
    it 'refuses a LegalPerson slot value carrying no sdg:LegalPerson, under R-EDM-REQ-S047' do
      stripped = with_body do |body|
        body.sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) { hollow_slot('LegalPerson') }
      end

      expect { stripped.validate! }.to refusing('R-EDM-REQ-S047')
    end
  end

  # `R-EDM-REQ-S052` and `S053`, whose common context is a `rim:SlotValue`
  # declaring itself `rim:CollectionValueType` — the attribute compared whole,
  # prefix included, where the nineteen rules above compare its local name
  # alone. No ancestor narrows that context: every slot value is reached.
  describe 'what a RegRep collection must carry' do
    def collection(name, &) = with_body { |body| body.sub(slot(name), &) }

    it 'refuses one carrying no element at all, under R-EDM-REQ-S052' do
      emptied = collection('Requirements') { |found| found.sub(%r{<rim:Element.*?</rim:Element>}m, '') }

      expect { emptied.validate! }.to refusing('R-EDM-REQ-S052')
    end

    it 'refuses one declaring no collectionType, under R-EDM-REQ-S053' do
      untyped = collection('EvidenceRequester') { |found| found.sub(/\s*collectionType="[^"]*"/, '') }

      expect { untyped.validate! }.to refusing('R-EDM-REQ-S053')
    end

    # The rule admits the `Set` of the RegRep list and no other collection.
    it 'refuses one declared a Bag' do
      bagged = collection('EvidenceRequester') do |found|
        found.sub(/collectionType="[^"]*"/, 'collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Bag"')
      end

      expect { bagged.validate! }.to refusing('R-EDM-REQ-S053')
    end

    # The two readings of `@xsi:type` told apart, on a slot value that breaks
    # both of these rules and satisfies `R-EDM-REQ-S026`: the local name is the
    # one that rule asks for, and the qualified name is not the one this context
    # selects. A reader unifying the two comparisons refuses this request.
    # Its `collectionType` is dropped, which is what `R-EDM-REQ-S053` would
    # refuse if this slot value were in its context. The `rim:Element` stays:
    # `S051` weighs every slot value of the document, whatever it declares
    # itself to be, so emptying this one would refuse the request for a reason
    # that has nothing to do with what is being proved here.
    it 'accepts one whose prefix keeps it out of the context of these two rules' do
      served = collection('Requirements') do |found|
        found.sub(/ xsi:type="[^"]*"/,
          %( xsi:type="x:CollectionValueType" xmlns:x="#{OotsNamespaces::NAMESPACES.fetch('rim')}"))
          .sub(/\s*collectionType="[^"]*"/, '')
      end

      expect(served.validate!).to be(served)
    end
  end

  # RG26: `R-EDM-REQ-S019` closes the list of slots on the 1.2 line.
  describe 'the preview slots on the 1.2 line' do
    it 'refuses a ReturnLocation, under R-EDM-REQ-S019' do
      request = received(second_request(location: nil, line: :v1_2,
        slots: preview_slots('https://oots.example/p', 'https://portail.example')))

      expect { request.validate! }.to refusing('R-EDM-REQ-S019')
    end

    it 'refuses a PreviewMethod, under R-EDM-REQ-S019' do
      request = received(second_request(location: nil, line: :v1_2,
        slots: preview_slots('https://oots.example/p') + string_slot('PreviewMethod', 'GET')))

      expect { request.validate! }.to refusing('R-EDM-REQ-S019')
    end
  end

  it 'refuses the slot declared an any value, under R-EDM-REQ-S031' do
    expect { with_classifications(classification, type: 'rim:AnyValueType').validate! }
      .to refusing('R-EDM-REQ-S031')
  end

  it 'refuses a collection element declared a collection, under R-EDM-REQ-S032' do
    expect { with_classifications(classification, element_type: 'rim:CollectionValueType').validate! }
      .to refusing('R-EDM-REQ-S032')
  end

  describe 'the slots each version defines' do
    # `ReturnLocation` is a slot 2.0.1 alone defines — the name appears nowhere
    # in the 1.2.5 Schematron, neither among the rules that type the slots nor
    # in the list `R-EDM-REQ-S019` closes. So the two lines refuse this same
    # declaration under two different rules, and refuse it for opposite reasons:
    # on the 2.0 line the slot exists and is mistyped, on the 1.2 one it does not
    # exist at all.
    def returning(envelope_of)
      envelope_of.call do |body|
        body.sub('<rim:Slot name="EvidenceRequester">') do
          '<rim:Slot name="ReturnLocation"><rim:SlotValue xsi:type="rim:AnyValueType">' \
            '<rim:Value>https://example.si/retour</rim:Value></rim:SlotValue></rim:Slot>' \
            '<rim:Slot name="EvidenceRequester">'
        end
      end
    end

    it 'refuses a ReturnLocation on the 1.2 line, under R-EDM-REQ-S019' do
      expect { received(returning(method(:earlier_line_envelope))).validate! }.to refusing('R-EDM-REQ-S019')
    end

    # And admits it on the line that defines it, which is what keeps the two
    # lists apart: a reader holding both lines to the 2.0 one would serve the
    # request above, and one holding both to the 1.2 one would refuse this.
    it 'admits a well-typed ReturnLocation on the 2.0 line' do
      written = with_body do |body|
        body.sub('<rim:Slot name="EvidenceRequester">') do
          "#{preview_slots('https://example.si/apercu', 'https://example.si/retour')}" \
            '<rim:Slot name="EvidenceRequester">'
        end
      end

      expect(written.validate!).to be(written)
    end

    it 'refuses that same declaration on the 2.0 line, under R-EDM-REQ-S061' do
      expect { returning(method(:with_body)).validate! }.to refusing('R-EDM-REQ-S061')
    end

    # The other face of `R-EDM-REQ-S022` on this line, and the one an accepted
    # request cannot prove: a slot typed as 2.0 types it — the very shape the
    # 2.0 table imposed on 1.2 correspondents — has to be refused here, or the
    # row is a transcription nothing exercises.
    it 'refuses a Procedure declared as the 2.0 line types it, under R-EDM-REQ-S022' do
      written = earlier_line_envelope do |body|
        body.sub('xsi:type="rim:InternationalStringValueType"', 'xsi:type="rim:StringValueType"')
      end

      expect { received(written).validate! }.to refusing('R-EDM-REQ-S022')
    end
  end

  describe 'the slot a legal person travels in' do
    def about_an_organisation(&) = received(envelope_about_an_organisation(legal_person_slot.then(&)))

    # `R-EDM-REQ-S034` type ce slot-là comme `S035` type son jumeau : le
    # `rim:AnyValueType` de l'exemple ci-dessus est ce que la règle demande, et
    # rien d'autre ne le satisfait.
    it 'refuses the slot declared a collection, under R-EDM-REQ-S034' do
      collected = about_an_organisation { |slot| slot.sub('rim:AnyValueType', 'rim:CollectionValueType') }

      expect { collected.validate! }.to refusing('R-EDM-REQ-S034')
    end
  end
end
