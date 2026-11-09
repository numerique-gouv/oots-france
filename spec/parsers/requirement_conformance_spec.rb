require 'rails_helper'

RSpec.describe RequirementConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to the slot the family judges' do
    def reduced(identifier)
      requirement = "<sdg:Requirement><sdg:Identifier>#{identifier}</sdg:Identifier>" \
                    '<sdg:Name lang="EN">Proof of diploma</sdg:Name></sdg:Requirement>'

      described_class.new(query_request(
        '<rim:Slot name="Requirements"><rim:SlotValue xsi:type="rim:CollectionValueType">' \
        "<rim:Element xsi:type=\"rim:AnyValueType\">#{requirement}</rim:Element></rim:SlotValue></rim:Slot>"
      ), specification: EdmSpecification::V2_0)
    end

    it 'accepts a requirement the Semantic Repository identifies' do
      expect(reduced('https://sr.oots.tech.ec.europa.eu/requirements/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee').validate!)
        .to be_a(described_class)
    end

    it 'refuses one it does not, under R-EDM-REQ-C008' do
      expect { reduced('https://example.org/requirements/1').validate! }.to refusing('R-EDM-REQ-C008')
    end
  end

  # Chapter 4.6 on the obligations a request invokes. `R-EDM-REQ-S011` counts
  # the slot; the five others fire on the elements a requirement carries, so
  # nothing counts the requirements themselves and a requirement carrying no
  # identifier at all breaks no assertion.
  describe 'the requirements the request invokes' do
    # Scoped to the slot rather than applied to the whole body: `sdg:Identifier`
    # also names the beneficiary and every agent, and `sdg:Name` names the
    # agents too — a substitution over the message would judge those instead.
    def with_requirements(&)
      with_body { |body| body.sub(%r{<rim:Slot name="Requirements">.*?</rim:Slot>}m, &) }
    end

    def identified_by(value)
      with_requirements do |slot|
        slot.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, "<sdg:Identifier>#{value}</sdg:Identifier>")
      end
    end

    # Through a block, so that a backslash in a wording is a backslash: `sub`
    # reads `\1` and `\&` in a replacement string as references.
    def worded(*wordings)
      with_requirements { |slot| slot.sub(%r{<sdg:Name.*?</sdg:Name>}m) { wordings.join } }
    end

    def besides(requirement)
      with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m) { |first| first + requirement } }
    end

    def alongside(requirement)
      with_requirements do |slot|
        slot.sub(%r{<rim:Element.*?</rim:Element>}m) do |first|
          %(#{first}<rim:Element xsi:type="rim:AnyValueType">#{requirement}</rim:Element>)
        end
      end
    end

    def requirement_named(id)
      %(<sdg:Requirement><sdg:Identifier>#{id}</sdg:Identifier><sdg:Name lang="DA">Andet krav</sdg:Name></sdg:Requirement>)
    end

    it 'accepts the requirement the real request carries' do
      expect(request.validate!).to be(request)
    end

    # `R-EDM-REQ-S037` fires on the `rim:Element` itself, which is there — it
    # came out of the collection. That is what separates it from `C008`, whose
    # own context node is the one missing when a requirement carries no
    # identifier, and which is therefore silent where this one refuses.
    it 'refuses a collection element carrying no requirement, under R-EDM-REQ-S037' do
      emptied = with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m, '') }

      expect { emptied.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-S037')))
    end

    # Nothing counts the requirements — `S011` counts the slot — so two of them
    # are conformant, and each is judged on its own. A reader that stopped at
    # the first would serve the second unexamined.
    describe 'a request naming two obligations' do
      it 'accepts them when both conform' do
        doubled = besides(requirement_named('https://sr.acc.oots.tech.ec.europa.eu/requirements/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))

        expect(doubled.validate!).to be(doubled)
      end

      it 'judges the second as much as the first' do
        doubled = besides(requirement_named('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42'))

        expect { doubled.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end
    end

    # `besides` puts the second requirement in the same `rim:Element`; these put
    # it in an element of its own. The two are different loops — `slot_elements`
    # walks the collection, `all(element, './sdg:Requirement')` walks inside one
    # — and a regression collapsing the outer one would survive the tests above.
    describe 'a collection naming its obligations in separate elements' do
      it 'accepts them when both conform' do
        spread = alongside(requirement_named('https://sr.acc.oots.tech.ec.europa.eu/requirements/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))

        expect(spread.validate!).to be(spread)
      end

      it 'judges the requirement of the second element' do
        spread = alongside(requirement_named('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42'))

        expect { spread.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end
    end

    describe 'the identifier of a requirement' do
      it 'refuses one that is not a Semantic Repository URL, under R-EDM-REQ-C008' do
        expect { identified_by('urn:uuid:f8a6a284-34e9-42c7-9733-63b5c4f4aa42').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end

      # The assertion carries no `i` flag and spells the UUID `[a-f0-9]`, where
      # `R-EDM-REQ-S004` on the request's own identifier matches case-insensitively.
      it 'refuses a UUID written in upper case' do
        expect { identified_by('https://sr.oots.tech.ec.europa.eu/requirements/F8A6A284-34E9-42C7-9733-63B5C4F4AA42').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C008')))
      end

      it 'names the requirement whose identifier is there and empty' do
        expect { identified_by('').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C008', message: /« vide »/)))
      end

      it 'accepts the acceptance environment, whose midfix the rule provides for' do
        accepted = identified_by('https://sr.acc.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42')

        expect(accepted.validate!).to be(accepted)
      end

      # The assertion escapes the point of the optional midfix and no other, so
      # every remaining `.` matches any character — a hyphen included. Copied
      # from the Schematron rather than tightened: `Requirement::IDENTIFIER`,
      # which escapes them, would refuse what a FATAL rule admits.
      it 'accepts a host the unescaped points of the rule let through' do
        hyphenated = identified_by('https://sr-oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42')

        expect(hyphenated.validate!).to be(hyphenated)
      end

      # The context of `R-EDM-REQ-C008` is the identifier itself: absent, it
      # triggers no assertion at all, and inventing a refusal would name a rule
      # the request did not break.
      it 'says nothing of a requirement carrying no identifier' do
        amputated = with_requirements { |slot| slot.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, '') }

        expect(amputated.validate!).to be(amputated)
      end
    end

    # `R-EDM-REQ-C010` and `C094` assert the attribute is there, `C009` and
    # `C093` compare it to the code list — the same pair `C109` and `C108`
    # apply to an agent's name, under four other identifiers.
    # `R-EDM-REQ-S037` asserts `sdg:Requirement` and nothing of what it holds,
    # so an empty one satisfies it — as it satisfies `S038`, whose count of
    # named children equals a count of none. Nothing else has a context to fire
    # on. The silence is the rules', not an oversight, and it is pinned so that
    # closing it later is a decision rather than an accident.
    it 'says nothing of a requirement carrying neither identifier nor wording' do
      hollow = with_requirements { |slot| slot.sub(%r{<sdg:Requirement>.*?</sdg:Requirement>}m, '<sdg:Requirement/>') }

      expect(hollow.validate!).to be(hollow)
    end

    describe 'the language a wording names' do
      # The sentence is asserted beside the rule, and not for thoroughness:
      # `REQUIREMENT_WORDINGS` says which row of `AgentConformance::RULES` an
      # element is read under, so a table pointing `sdg:Name` at the
      # description's row would name the wrong element in the sentence an
      # operator reads in the journal. Asserting both pins the mapping, where
      # asserting the rule alone pins only half of it.
      it 'refuses a name carrying no lang, under R-EDM-REQ-C010' do
        expect { worded('<sdg:Name>Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C010', message: /Le nom d'une exigence/)))
      end

      it 'refuses a name whose lang is not a code of the list, under R-EDM-REQ-C009' do
        expect { worded('<sdg:Name lang="en">Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end

      # The context of `C009` is the attribute node, whose value is not
      # normalised: ` EN ` satisfies `C010`, which normalises, and breaks the
      # comparison that follows it.
      it 'refuses a lang padded with blanks, which the rule before it accepts' do
        expect { worded('<sdg:Name lang=" EN ">Proof of diploma</sdg:Name>').validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end

      it 'refuses a description carrying no lang, under R-EDM-REQ-C094' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description>Awarded by a tertiary institution</sdg:Description>')

        expect { described.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: 'R-EDM-REQ-C094', message: /La description d'une exigence/)))
      end

      it 'refuses a description whose lang is not a code of the list, under R-EDM-REQ-C093' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description lang="xx">Awarded by a tertiary institution</sdg:Description>')

        expect { described.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C093')))
      end

      # `RequirementType` makes `sdg:Description` `0..n`: the fixture carries
      # none, and one that names its language is served. Tested on the
      # accepting side too, where a row of `REQUIREMENT_WORDINGS` naming the
      # wrong key would otherwise go unnoticed — the refusals above would still
      # fire, under the right rule, with the wrong sentence.
      it 'accepts a description whose lang is a code of the list' do
        described = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Description lang="DA">Bevis for eksamensbevis</sdg:Description>')

        expect(described.validate!).to be(described)
      end

      # Every wording is judged, and not the first alone: chapter 4.5.1 makes
      # `sdg:Name` `1..n`, and each rule fires per wording — two on the element,
      # two on its `lang`.
      it 'accepts a requirement worded in two languages' do
        bilingual = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Name lang="DA">Bevis for eksamensbevis</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end

      it 'judges the second wording as much as the first' do
        bilingual = worded('<sdg:Name lang="EN">Proof of diploma</sdg:Name>',
          '<sdg:Name lang="da">Bevis for eksamensbevis</sdg:Name>')

        expect { bilingual.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C009')))
      end
    end

    # `R-EDM-REQ-S038` closes the list of what a requirement may carry:
    # `count(sdg:Name) + count(sdg:Identifier) + count(sdg:Description) = count(child::*)`.
    # The assertion, and not its message — which reads that the requirement
    # « MUST contain » the three, where the test requires none of them.
    describe 'the elements a requirement carries' do
      def carrying(element)
        with_requirements { |slot| slot.sub('</sdg:Name>') { "</sdg:Name>#{element}" } }
      end

      it 'refuses one carrying an sdg:ReferenceFramework, under R-EDM-REQ-S038' do
        framework = '<sdg:ReferenceFramework>Directive 2005/36/CE</sdg:ReferenceFramework>'

        expect { carrying(framework).validate! }.to refusing('R-EDM-REQ-S038')
      end

      it 'refuses one carrying an sdg:EvidenceTypeList' do
        expect { carrying('<sdg:EvidenceTypeList/>').validate! }.to refusing('R-EDM-REQ-S038')
      end

      # What the message of the rule would refuse and its test admits, which is
      # the requirement the real request carries: an identifier, a name, and no
      # description at all.
      it 'accepts one carrying an identifier and a name and no description' do
        expect(request.validate!).to be(request)
      end

      # Only the names are closed, not how many of each: the assertion counts
      # every `sdg:Name` on its left-hand side.
      it 'accepts one carrying a second name' do
        bilingual = carrying('<sdg:Name lang="DA">Bevis for eksamensbevis</sdg:Name>')

        expect(bilingual.validate!).to be(bilingual)
      end
    end
  end
end
