require 'rails_helper'

RSpec.describe DescribedPersonConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to what the family judges' do
    def reduced(person)
      described_class.new(query_request(
        '<query:Query><rim:Slot name="AuthorizedRepresentative"><rim:SlotValue xsi:type="rim:AnyValueType">' \
        "<sdg:Person>#{person}</sdg:Person></rim:SlotValue></rim:Slot></query:Query>"
      ), specification: EdmSpecification::V2_0)
    end

    it 'accepts a representative declaring its level of assurance' do
      expect(reduced('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>').validate!).to be_a(described_class)
    end

    it 'refuses one declaring none, under R-EDM-REQ-C058' do
      expect { reduced('').validate! }.to refusing('R-EDM-REQ-C058')
    end
  end

  # The four people a request describes — the subject and its representative,
  # natural or legal — judged by one battery of rules published four times over.
  # None of these values is read for anything but the refusal: France models
  # neither the representative nor the address of a subject.
  describe 'the people the request describes' do
    # Written into the reference request, which names none: every context here
    # is an element of a slot that is *there*, so an absent representative
    # triggers nothing at all.
    def representing(content, name: 'AuthorizedRepresentative', element: 'sdg:Person')
      written = "<rim:Slot name=\"#{name}\"><rim:SlotValue xsi:type=\"rim:AnyValueType\">" \
                "<#{element}>#{content}</#{element}></rim:SlotValue></rim:Slot>"

      with_body { |body| body.sub('<rim:Slot name="NaturalPerson">') { "#{written}<rim:Slot name=\"NaturalPerson\">" } }
    end

    # The least a representative may be and still break no rule: `C058` asks for
    # the level of assurance, and nothing else is required of a person carrying
    # no identifier — `C060`, which would ask for its value, is `WARNING`.
    def represented_by(extra = '') = representing("<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>#{extra}")

    def organisation_representing(extra = '')
      representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                   "<sdg:LegalPersonIdentifier schemeID=\"eidas\">SI/SI/123456</sdg:LegalPersonIdentifier>#{extra}",
        name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')
    end

    # Written into the `sdg:Person` the reference request already names.
    def subject_carrying(extra)
      with_body { |body| body.sub('</sdg:Person>') { "#{extra}</sdg:Person>" } }
    end

    # And the organisation subject, which the reference request does not name:
    # `Fixtures#legal_person_slot` is the conformant one the rest of this file
    # reads, so what an example changes in it is the only thing under test.
    def about_an_organisation(&) = received(envelope_about_an_organisation(legal_person_slot.then(&)))

    it 'serves a request naming no representative at all, as the reference one does' do
      expect(request.validate!).to be(request)
    end

    it 'serves one naming a representative that breaks nothing' do
      written = represented_by

      expect(written.validate!).to be(written)
    end

    # The ten country codes, one assertion under ten identifiers — every row of
    # the table, refused and accepted. A row nothing exercises is a row that
    # could name the wrong rule, or point at the wrong element, without anything
    # saying so.
    describe 'the country codes each of them names' do
      def carrying(person, written)
        case person
        when :subject then subject_carrying(written)
        when :legal_subject then about_an_organisation { |slot| slot.sub('</sdg:LegalPerson>') { "#{written}</sdg:LegalPerson>" } }
        when :representative then represented_by(written)
        else organisation_representing(written)
        end
      end

      {
        'R-EDM-REQ-C045' => [:subject, '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
        'R-EDM-REQ-C075' => [:subject, '<sdg:Nationality>%s</sdg:Nationality>'],
        'R-EDM-REQ-C076' => [:subject, '<sdg:CountryOfBirth>%s</sdg:CountryOfBirth>'],
        'R-EDM-REQ-C077' => [:subject, '<sdg:CountryOfResidence>%s</sdg:CountryOfResidence>'],
        'R-EDM-REQ-C056' => [:legal_subject,
                             '<sdg:RegisteredAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:RegisteredAddress>'],
        'R-EDM-REQ-C067' => [:representative,
                             '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
        'R-EDM-REQ-C078' => [:representative, '<sdg:Nationality>%s</sdg:Nationality>'],
        'R-EDM-REQ-C079' => [:representative, '<sdg:CountryOfBirth>%s</sdg:CountryOfBirth>'],
        'R-EDM-REQ-C080' => [:representative, '<sdg:CountryOfResidence>%s</sdg:CountryOfResidence>'],
        # The one row whose element the schema does not admit where the rule
        # looks for it: `sdg:LegalPerson` gets an `sdg:RegisteredAddress` and no
        # `sdg:CurrentAddress`. Transcribed to the letter all the same, so the
        # request that reaches it is one no schema-valid correspondent sends.
        'R-EDM-REQ-C090' => [:legal_representative,
                             '<sdg:CurrentAddress><sdg:AdminUnitLevel1>%s</sdg:AdminUnitLevel1></sdg:CurrentAddress>'],
      }.each do |rule, (person, written)|
        it "refuses a code the list does not publish, under #{rule}" do
          expect { carrying(person, format(written, 'ZZ')).validate! }.to refusing(rule)
        end

        # Compared exactly, the assertion carrying no `i` flag: the refusal
        # above would pass just as well if the reader accepted nothing at all,
        # and this is what says otherwise.
        it "accepts a published code in the same place, for #{rule}" do
          accepted = carrying(person, format(written, 'SI'))

          expect(accepted.validate!).to be(accepted)
        end
      end
    end

    describe 'the level of assurance each of them declares' do
      it 'refuses a representative carrying none, under R-EDM-REQ-C058' do
        expect { representing('<sdg:FamilyName>Novak</sdg:FamilyName>').validate! }
          .to refusing('R-EDM-REQ-C058')
      end

      it 'refuses one outside the LoA list, under R-EDM-REQ-C059' do
        expect { representing('<sdg:LevelOfAssurance>Medium</sdg:LevelOfAssurance>').validate! }
          .to refusing('R-EDM-REQ-C059')
      end

      it 'refuses an organisation subject carrying none, under R-EDM-REQ-C047' do
        stripped = about_an_organisation { |slot| slot.sub(%r{<sdg:LevelOfAssurance>.*?</sdg:LevelOfAssurance>}, '') }

        expect { stripped.validate! }.to refusing('R-EDM-REQ-C047')
      end

      it 'refuses one outside the list, under R-EDM-REQ-C048' do
        lowered = about_an_organisation { |slot| slot.sub('<sdg:LevelOfAssurance>High', '<sdg:LevelOfAssurance>Medium') }

        expect { lowered.validate! }.to refusing('R-EDM-REQ-C048')
      end
    end

    describe 'the scheme each identifier names' do
      it 'refuses an organisation subject whose identifier names none, under R-EDM-REQ-C052' do
        stripped = about_an_organisation { |slot| slot.sub(' schemeID="eidas"', '') }

        expect { stripped.validate! }.to refusing('R-EDM-REQ-C052')
      end

      it 'refuses one naming another scheme, under R-EDM-REQ-C053' do
        other = about_an_organisation { |slot| slot.sub('schemeID="eidas"', 'schemeID="eidas2"') }

        expect { other.validate! }.to refusing('R-EDM-REQ-C053')
      end

      # And the same pair on the representative, under its own identifiers.
      it 'refuses a representative identifier naming no scheme at all, under R-EDM-REQ-C062' do
        expect { represented_by('<sdg:Identifier>SI/SI/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C062')
      end

      it 'refuses a representative naming another scheme, under R-EDM-REQ-C063' do
        expect { represented_by('<sdg:Identifier schemeID="eidas2">SI/SI/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C063')
      end

      # Which is what empties the `eidas2` branch: `C121`, `C122`, `C123`, `C125`
      # and `C127` narrow their contexts to a representative identified under
      # that very scheme, so none of them is ever reached. The `detail` carries
      # one rule, and this is what proves it is always this one — a
      # representative breaking every rule of that branch at once is refused by
      # `C063` and named by nothing else.
      it 'never names a rule of the eidas2 branch, whose context lies past that refusal' do
        eidas2 = represented_by('<sdg:Identifier schemeID="eidas2">pas-un-identifiant</sdg:Identifier>' \
                                '<sdg:LevelOfAssurance>Low</sdg:LevelOfAssurance>')

        expect { eidas2.validate! }.to refusing('R-EDM-REQ-C063')
      end
    end

    # The legal representative's chain, jumelle for jumelle of the legal
    # subject's: level of assurance, then the scheme of its eIDAS identifier.
    describe 'the organisation representing the subject' do
      def carrying(written)
        representing("<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>#{written}",
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')
      end

      it 'refuses one carrying no level of assurance, under R-EDM-REQ-C082' do
        written = representing('<sdg:LegalPersonIdentifier schemeID="eidas">SI/SI/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C082')
      end

      it 'refuses one outside the LoA list, under R-EDM-REQ-C083' do
        written = representing('<sdg:LevelOfAssurance>Medium</sdg:LevelOfAssurance>' \
                               '<sdg:LegalPersonIdentifier schemeID="eidas">SI/SI/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C083')
      end

      it 'refuses an identifier naming no scheme, under R-EDM-REQ-C086' do
        expect { carrying('<sdg:LegalPersonIdentifier>SI/SI/123456</sdg:LegalPersonIdentifier>').validate! }
          .to refusing('R-EDM-REQ-C086')
      end

      it 'refuses one naming another scheme, under R-EDM-REQ-C087' do
        expect { carrying('<sdg:LegalPersonIdentifier schemeID="eidas2">SI/SI/123456</sdg:LegalPersonIdentifier>').validate! }
          .to refusing('R-EDM-REQ-C087')
      end

      it 'serves one that breaks none of the four' do
        written = organisation_representing

        expect(written.validate!).to be(written)
      end
    end

    describe 'the shape of an eIDAS identifier' do
      it 'refuses a representative whose country codes are not published, under R-EDM-REQ-C061' do
        expect { represented_by('<sdg:Identifier schemeID="eidas">ZZ/FR/123456</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C061')
      end

      it 'refuses an organisation representative under R-EDM-REQ-C085' do
        written = representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>' \
                               '<sdg:LegalPersonIdentifier schemeID="eidas">ZZ/FR/123456</sdg:LegalPersonIdentifier>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C085')
      end

      # The accept half of `C061`, `C062`, `C063` and `C126` at once: a
      # representative identified under `eidas`, with country codes the list
      # publishes and a sex the eIDAS profile admits, is served.
      it 'serves a representative whose eIDAS identifier is well formed' do
        written = represented_by('<sdg:Identifier schemeID="eidas">SI/SI/123456</sdg:Identifier>' \
                                 '<sdg:Gender>Female</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      it 'refuses an organisation representative carrying no identifier, under R-EDM-REQ-C084' do
        written = representing('<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>',
          name: 'AuthorizedRepresentativeLegalPerson', element: 'sdg:LegalPerson')

        expect { written.validate! }.to refusing('R-EDM-REQ-C084')
      end
    end

    describe 'the optional identifiers of an organisation representative' do
      it 'refuses one naming no scheme, under R-EDM-REQ-C088' do
        expect { organisation_representing('<sdg:Identifier>FR12345678901</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C088')
      end

      # A SIRET identifies an agent of the exchange and never the subject of an
      # evidence: the `IdentifierSchemes` list does not publish it.
      it 'refuses one naming a scheme the list does not publish, under R-EDM-REQ-C089' do
        expect { organisation_representing('<sdg:Identifier schemeID="SIRET">00000000000002</sdg:Identifier>').validate! }
          .to refusing('R-EDM-REQ-C089')
      end

      it 'accepts one the list does publish' do
        written = organisation_representing('<sdg:Identifier schemeID="VAT">FR12345678901</sdg:Identifier>')

        expect(written.validate!).to be(written)
      end
    end

    describe 'the date of birth of a representative' do
      it 'refuses one that is not a date, under R-EDM-REQ-C064' do
        expect { represented_by('<sdg:DateOfBirth>hier</sdg:DateOfBirth>').validate! }
          .to refusing('R-EDM-REQ-C064')
      end

      # Anchored at both ends, where `C002` is anchored at neither.
      it 'refuses a timestamp where a date is asked for' do
        expect { represented_by('<sdg:DateOfBirth>1980-01-01T00:00:00Z</sdg:DateOfBirth>').validate! }
          .to refusing('R-EDM-REQ-C064')
      end

      it 'accepts a date written as the rule asks' do
        written = represented_by('<sdg:DateOfBirth>1980-01-01</sdg:DateOfBirth>')

        expect(written.validate!).to be(written)
      end
    end

    describe 'the sex of a representative' do
      def identified_as(gender)
        represented_by("<sdg:Identifier schemeID=\"eidas\">SI/SI/123456</sdg:Identifier>#{gender}")
      end

      it 'refuses a value outside the Gender list, under R-EDM-REQ-C124' do
        expect { represented_by('<sdg:Gender>7</sdg:Gender>').validate! }.to refusing('R-EDM-REQ-C124')
      end

      # `C124` admits the numeric profile; `C126` narrows it to the three eIDAS
      # values once an `eidas` identifier is there — so `1` passes the first and
      # falls on the second.
      it 'refuses the numeric profile under an eidas identifier, under R-EDM-REQ-C126' do
        expect { identified_as('<sdg:Gender>1</sdg:Gender>').validate! }.to refusing('R-EDM-REQ-C126')
      end

      # The assertion is on the *person* and reads `sdg:Gender=('Male',…)`,
      # which an absent element fails: its published sentence only constrains a
      # value, and the assertion is what plays. `docs/carte_des_tdd.md` records
      # the disagreement.
      it 'refuses an eidas representative carrying no sex at all, under the same rule' do
        expect { identified_as('').validate! }.to refusing('R-EDM-REQ-C126')
      end

      # `C124` admits the numeric profile and `C126` does not — but `C126` only
      # has a context once an `eidas` identifier is there. Without one, the
      # numeric value passes: this is the half that proves the two lists are
      # genuinely different, where refusing `7` proves only that both refuse it.
      it 'accepts a numeric sex on a representative naming no identifier' do
        written = represented_by('<sdg:Gender>1</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      it 'accepts an eidas representative naming one of the three' do
        written = identified_as('<sdg:Gender>Female</sdg:Gender>')

        expect(written.validate!).to be(written)
      end

      # Neither rule exists at the 1.2.5 tag, so a request of that line writes
      # the element as it likes — the pair that proves the predicate guarding
      # them has the polarity it should.
      it 'says nothing of the sex of a representative on the 1.2 line' do
        written = earlier_line_envelope do |body|
          body.sub('<rim:Slot name="NaturalPerson">') do
            '<rim:Slot name="AuthorizedRepresentative"><rim:SlotValue xsi:type="rim:AnyValueType"><sdg:Person>' \
              '<sdg:LevelOfAssurance>High</sdg:LevelOfAssurance><sdg:Gender>7</sdg:Gender>' \
              '</sdg:Person></rim:SlotValue></rim:Slot><rim:Slot name="NaturalPerson">'
          end
        end

        expect(received(written).validate!).to be_a(described_class)
      end
    end

    # `C081` compares the value whole — `or` being the loosest operator of
    # XPath — where `C091` splits on `,\s*`. The pair on one and the same value
    # is what proves the two assertions are read differently, whatever their
    # messages both say about comma-separated values.
    describe 'the procedures a power of representation covers' do
      def scoped(value, person: method(:represented_by))
        person.call('<sdg:SectorSpecificAttribute><sdg:AttributeName>' \
                    'http://data.europa.eu/p4s/attributes/PowerOfRepresentationScope</sdg:AttributeName>' \
                    "<sdg:AttributeValue>#{value}</sdg:AttributeValue></sdg:SectorSpecificAttribute>")
      end

      it 'refuses a comma-separated pair on a natural representative, under R-EDM-REQ-C081' do
        expect { scoped('T1,T3').validate! }.to refusing('R-EDM-REQ-C081')
      end

      it 'accepts that same pair on an organisation representative, which C091 splits' do
        written = scoped('T1,T3', person: method(:organisation_representing))

        expect(written.validate!).to be(written)
      end

      it 'refuses a split value naming a code the list does not publish, under R-EDM-REQ-C091' do
        expect { scoped('T1, Z9', person: method(:organisation_representing)).validate! }
          .to refusing('R-EDM-REQ-C091')
      end

      it 'accepts the system check code, which both admit beside the list' do
        written = scoped('00')

        expect(written.validate!).to be(written)
      end

      # Neither context stops at the URI its message names, so every sectoral
      # attribute is judged — the assertion, and not its message.
      it 'judges an attribute of another URI just the same' do
        written = represented_by('<sdg:SectorSpecificAttribute><sdg:AttributeName>urn:example:autre' \
                                 '</sdg:AttributeName><sdg:AttributeValue>Z9</sdg:AttributeValue>' \
                                 '</sdg:SectorSpecificAttribute>')

        expect { written.validate! }.to refusing('R-EDM-REQ-C081')
      end
    end
  end
end
