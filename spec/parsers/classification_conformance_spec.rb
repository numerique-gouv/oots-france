require 'rails_helper'

RSpec.describe ClassificationConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to the slot the family judges' do
    def reduced(*classifications)
      slot = classification_slot(*classifications).sub('<rim:Slot name="EvidenceRequester">', '')

      described_class.new(query_request(slot), specification: EdmSpecification::V2_0)
    end

    it 'accepts the classification chapter 4.5.1 publishes as an example' do
      expect(reduced(classification).validate!).to be_a(described_class)
    end

    it 'refuses a type the chapter does not publish, under R-EDM-REQ-C095' do
      expect { reduced(classification(type: 'date')).validate! }.to refusing('R-EDM-REQ-C095')
    end
  end

  # Chapter 4.6 on the classifications of provider a request invokes.
  # `R-EDM-REQ-S014` counts the slot under `CAUTION`, so a request carrying none
  # is one nothing refuses — which is the request really received. Seventeen
  # FATAL rules fire below that slot: on each element of the collection, then on
  # each classification's identifier, its type, the value it retains, what the
  # type `codelist` adds, and the language of each description.
  describe 'the provider classifications the request invokes' do
    # `R-EDM-REQ-S014` is a `CAUTION`: its absence is refused nowhere, which is
    # why the slot is read through `optional_slot_elements` and stays out of
    # `REQUIRED_SLOTS`.
    it 'accepts a request carrying no such slot, which is the one really received' do
      expect(request.validate!).to be(request)
    end

    it 'accepts the classification chapter 4.5.1 publishes as an example' do
      expect(with_classifications(classification).validate!).to be_truthy
    end

    # `R-EDM-REQ-S041` fires on the `rim:Element` itself, which is there — it
    # came out of the collection — exactly as `S037` does over `Requirements`.
    it 'refuses a collection element carrying no classification, under R-EDM-REQ-S041' do
      expect { with_classifications('').validate! }.to refusing('R-EDM-REQ-S041')
    end

    # `InformationConceptType` sets no upper bound, so one `rim:Element` may
    # carry several classifications and each is judged on its own. Distinct from
    # the case below, which puts each classification in an element of its own:
    # this one alone exercises the inner walk.
    it 'judges a second classification carried by the same element' do
      doubled = with_classifications(
        classification + classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County')
      )

      expect { doubled.validate! }.to refusing('R-EDM-REQ-C098')
    end

    # Nothing counts the classifications, `S014` counting the slot: each
    # element is judged on its own, so a reader stopping at the first would
    # serve the second unexamined.
    it 'judges a second element as much as the first' do
      doubled = with_classifications(classification, classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County'))

      expect { doubled.validate! }.to refusing('R-EDM-REQ-C098')
    end

    # `R-EDM-REQ-C019`: a bare UUID, `urn:uuid:` and all, with neither the
    # version nibble nor the variant one constrained. Its context is the
    # identifier itself, so a classification carrying none breaks nothing.
    describe 'the identifier it names itself by' do
      it 'refuses a name that is no UUID at all, under R-EDM-REQ-C019' do
        expect { with_classifications(classification(id: 'FR-MUNICIPALITY')).validate! }
          .to refusing('R-EDM-REQ-C019')
      end

      # The assertion carries the `i` flag, where `C008`'s over a requirement's
      # identifier does not: the same hexadecimal, judged the other way round.
      it 'accepts a UUID written in upper case' do
        upper = classification(id: '5CE148B9-5578-4049-AECF-AF7BB55714B5')

        expect(with_classifications(upper).validate!).to be_truthy
      end

      # `normalize-space` is applied before matching, so blanks around the
      # value are none of the rule's business.
      it 'accepts a UUID padded with blanks' do
        padded = classification(id: "\n      5ce148b9-5578-4049-aecf-af7bb55714b5\n    ")

        expect(with_classifications(padded).validate!).to be_truthy
      end

      # Written empty, the element is there and is a context node: the assertion
      # fires on a value the sentence then has nothing to name.
      it 'refuses an identifier written empty, under R-EDM-REQ-C019' do
        expect { with_classifications(classification(id: '')).validate! }.to refusing('R-EDM-REQ-C019')
      end

      # The prefix `R-EDM-REQ-S004` puts on the request's own identifier, which
      # this rule does not admit: its pattern is anchored on both ends.
      it 'refuses a UUID prefixed urn:uuid:, which the request identifier carries' do
        prefixed = classification(id: 'urn:uuid:5ce148b9-5578-4049-aecf-af7bb55714b5')

        expect { with_classifications(prefixed).validate! }.to refusing('R-EDM-REQ-C019')
      end

      # The context of `C019` is the identifier: a classification carrying none
      # fires nothing here. `C096` is what asserts one, and only where the type
      # is `codelist`.
      it 'accepts a classification of type string carrying no identifier at all' do
        unnamed = classification(type: 'string', expression: nil).sub(%r{<sdg:Identifier.*?</sdg:Identifier>}, '')

        expect(with_classifications(unnamed).validate!).to be_truthy
      end
    end

    # The three rules the `@schemeID` of that identifier carries: `C097` on its
    # shape, `C098` on the country it names and `C099` on its last segment. The
    # first two have the attribute for context and say nothing of an identifier
    # carrying none; the third narrows its own to `sdg:Identifier[@schemeID]`.
    describe 'the scheme its identifier names' do
      # `R-EDM-REQ-C097` copied dot for dot: only the point of the optional
      # environment midfix is escaped in the assertion, so every other one
      # matches any character at all.
      it 'accepts a scheme whose first point is any character, as the rule reads it' do
        loose = classification(scheme: 'https://sr-oots.tech.ec.europa.eu/codelists/DE/Lau2022')

        expect(with_classifications(loose).validate!).to be_truthy
      end

      it 'accepts an acceptance URL, whose midfix the pattern provides for' do
        midfixed = classification(scheme: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FR/Municipality')

        expect(with_classifications(midfixed).validate!).to be_truthy
      end

      it 'refuses a scheme served over http, under R-EDM-REQ-C097' do
        insecure = classification(scheme: 'http://sr.oots.tech.ec.europa.eu/codelists/DE/Lau2022')

        expect { with_classifications(insecure).validate! }.to refusing('R-EDM-REQ-C097')
      end

      # The pattern carries no `i` flag: the country segment is `[A-Z]{2}` and
      # `de` is not one — which `C098` would refuse too, the shape being judged
      # first.
      it 'refuses a country written in lower case, under R-EDM-REQ-C097' do
        lowered = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/fr/Municipality')

        expect { with_classifications(lowered).validate! }.to refusing('R-EDM-REQ-C097')
      end

      # `oots` is admitted on an agent's identifier « for testing purposes » and
      # by no rule here: it is neither `[A-Z]{2}` nor a code of the
      # `OOTS_Country-CodeList`.
      it 'refuses the literal oots, which the agent rules admit' do
        tested = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/oots/Municipality')

        expect { with_classifications(tested).validate! }.to refusing('R-EDM-REQ-C097')
      end

      it 'refuses a scheme ending at the country, with no short name after it' do
        truncated = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/FR')

        expect { with_classifications(truncated).validate! }.to refusing('R-EDM-REQ-C097')
      end

      # Present and empty, the attribute is a context node of its own: the
      # assertion fires on a value that matches nothing.
      it 'refuses a schemeID written empty, under R-EDM-REQ-C097' do
        expect { with_classifications(classification(scheme: '')).validate! }.to refusing('R-EDM-REQ-C097')
      end

      # `R-EDM-REQ-C098` reads the country between the codelist prefix and the
      # next `/`, and compares it to the countries taking part in OOTS — a far
      # shorter list than the one `C015` holds an address to. The case that
      # separates it from `C097`: `US` is a well-formed segment of a
      # well-formed URL, and no country of the list.
      it 'refuses a well-formed scheme naming no participating country, under R-EDM-REQ-C098' do
        foreign = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/US/County')

        expect { with_classifications(foreign).validate! }.to refusing('R-EDM-REQ-C098')
      end

      it 'accepts a country taking part in OOTS' do
        accepted = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Municipality')

        expect(with_classifications(accepted).validate!).to be_truthy
      end

      # `R-EDM-REQ-C099` reads the last segment **without** normalising, where
      # `C097` normalises first: a `schemeID` ending in a blank is the one value
      # that breaks this rule and no other.
      it 'refuses a schemeID ending in a blank, under R-EDM-REQ-C099 alone' do
        padded = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Lau2022 ')

        expect { with_classifications(padded).validate! }.to refusing('R-EDM-REQ-C099')
      end

      it 'refuses a short name carrying a blank, under R-EDM-REQ-C097' do
        spaced = classification(scheme: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Lau 2022')

        expect { with_classifications(spaced).validate! }.to refusing('R-EDM-REQ-C097')
      end

      # `R-EDM-REQ-C096`, the one rule that requires the attribute at all, and
      # only of a classification typed `codelist`. `C097`, `C098` and `C099` say
      # nothing here, their contexts being the attribute or the identifier
      # carrying it.
      it 'refuses a code list naming no scheme, under R-EDM-REQ-C096' do
        expect { with_classifications(classification(scheme: nil)).validate! }.to refusing('R-EDM-REQ-C096')
      end

      it 'accepts a classification of another type naming no scheme' do
        untyped = classification(scheme: nil, type: 'string', expression: nil)

        expect(with_classifications(untyped).validate!).to be_truthy
      end

      # `C096` reads `sdg:Identifier/@schemeID`, which is the first such
      # attribute in document order and not the first identifier's: an
      # identifier carrying none is passed over rather than counted as an empty
      # one. A reader taking the first identifier's attribute would refuse this,
      # which the rule admits.
      it 'accepts a code list whose second identifier alone carries the scheme' do
        doubled = classification(scheme: nil).sub('</sdg:Identifier>',
          '</sdg:Identifier><sdg:Identifier schemeID="https://sr.oots.tech.ec.europa.eu/codelists/DE/Lau2022">' \
          '5ce148b9-5578-4049-aecf-af7bb55714b5</sdg:Identifier>')

        expect(with_classifications(doubled).validate!).to be_truthy
      end
    end

    # `R-EDM-REQ-C020` requires the type, `C095` holds it to the three published
    # values — compared raw, with neither `normalize-space` nor an `i` flag.
    describe 'the type it declares' do
      it 'refuses a classification carrying no type, under R-EDM-REQ-C020' do
        expect { with_classifications(classification(type: nil)).validate! }.to refusing('R-EDM-REQ-C020')
      end

      it 'refuses a type written blank, the rule normalising it' do
        expect { with_classifications(classification(type: '   ')).validate! }.to refusing('R-EDM-REQ-C020')
      end

      it 'refuses a published value in the wrong case, under R-EDM-REQ-C095' do
        expect { with_classifications(classification(type: 'Codelist')).validate! }.to refusing('R-EDM-REQ-C095')
      end

      # The value that separates the two rules: `C020` normalises, so a padded
      # type satisfies it, and `C095` compares raw, so it does not.
      it 'refuses a padded type under R-EDM-REQ-C095, C020 normalising it' do
        expect { with_classifications(classification(type: ' codelist ')).validate! }.to refusing('R-EDM-REQ-C095')
      end

      it 'refuses a type the chapter does not publish, under R-EDM-REQ-C095' do
        expect { with_classifications(classification(type: 'date')).validate! }.to refusing('R-EDM-REQ-C095')
      end

      it 'accepts the type string' do
        expect(with_classifications(classification(type: 'string', expression: nil)).validate!).to be_truthy
      end

      it 'accepts the type boolean' do
        boolean = classification(type: 'boolean', expression: nil,
          values: '<sdg:SupportedValue><sdg:BooleanValue>false</sdg:BooleanValue></sdg:SupportedValue>')

        expect(with_classifications(boolean).validate!).to be_truthy
      end
    end

    # `R-EDM-REQ-C023` asks for at least one supported value and none of them
    # empty, `C105` for exactly one — « along the answer chosen by the user » —
    # and `C103` and `C104` for the element the type obliges each to carry.
    #
    # `C102` is never named: its assertion is word for word `C023`'s under a
    # narrower context, so what it refuses `C023` refuses already.
    describe 'the value it retains' do
      it 'refuses a classification carrying no supported value, under R-EDM-REQ-C023' do
        expect { with_classifications(classification(type: 'string', expression: nil, values: '')).validate! }
          .to refusing('R-EDM-REQ-C023')
      end

      # The case where the context of `C102` does not even open: a type outside
      # the three published ones is `C095`'s to refuse, and the rule that counts
      # the values is `C023`, which narrows itself to nothing.
      it 'refuses a type of its own carrying no value under R-EDM-REQ-C095, never C102' do
        expect { with_classifications(classification(type: 'date', values: '')).validate! }
          .to refusing('R-EDM-REQ-C095')
      end

      it 'refuses a supported value that is empty, under R-EDM-REQ-C023' do
        empty = classification(type: 'boolean', expression: nil, values: '<sdg:SupportedValue></sdg:SupportedValue>')

        expect { with_classifications(empty).validate! }.to refusing('R-EDM-REQ-C023')
      end

      it 'refuses two supported values, under R-EDM-REQ-C105' do
        doubled = classification(values: '<sdg:SupportedValue><sdg:StringValue>11000000</sdg:StringValue></sdg:SupportedValue>' \
                                         '<sdg:SupportedValue><sdg:StringValue>02000000</sdg:StringValue></sdg:SupportedValue>')

        expect { with_classifications(doubled).validate! }.to refusing('R-EDM-REQ-C105')
      end

      # Both rules fire on this one: `C023` refuses the empty value, `C105` the
      # count. No rule of the chapter says which is named, and it is `C023` —
      # what the correspondent has to look at is the value, not the count.
      it 'refuses two supported values one of which is empty, under R-EDM-REQ-C023' do
        doubled = classification(values: '<sdg:SupportedValue><sdg:StringValue>11000000</sdg:StringValue></sdg:SupportedValue>' \
                                         '<sdg:SupportedValue></sdg:SupportedValue>')

        expect { with_classifications(doubled).validate! }.to refusing('R-EDM-REQ-C023')
      end

      it 'refuses a string value where the type string asks for one, under R-EDM-REQ-C103' do
        mistyped = classification(type: 'string', expression: nil,
          values: '<sdg:SupportedValue><sdg:BooleanValue>true</sdg:BooleanValue></sdg:SupportedValue>')

        expect { with_classifications(mistyped).validate! }.to refusing('R-EDM-REQ-C103')
      end

      it 'asks a code list for a string value too' do
        mistyped = classification(values: '<sdg:SupportedValue><sdg:BooleanValue>true</sdg:BooleanValue></sdg:SupportedValue>')

        expect { with_classifications(mistyped).validate! }.to refusing('R-EDM-REQ-C103')
      end

      it 'refuses a boolean value written as a string, under R-EDM-REQ-C104' do
        mistyped = classification(type: 'boolean', expression: nil,
          values: '<sdg:SupportedValue><sdg:StringValue>true</sdg:StringValue></sdg:SupportedValue>')

        expect { with_classifications(mistyped).validate! }.to refusing('R-EDM-REQ-C104')
      end
    end

    # `R-EDM-REQ-C100` and `C101`, whose context is a classification typed
    # `codelist`: the expression is required there, and required to be an
    # `https://` URL. A classification of another type owes neither.
    describe 'the expression a code list names' do
      it 'refuses a code list naming no expression, under R-EDM-REQ-C100' do
        expect { with_classifications(classification(expression: nil)).validate! }.to refusing('R-EDM-REQ-C100')
      end

      it 'accepts another type naming none' do
        expect(with_classifications(classification(type: 'string', expression: nil)).validate!).to be_truthy
      end

      it 'refuses an expression served over http, under R-EDM-REQ-C101' do
        insecure = classification(expression: 'http://query.cs.oots.tech.ec.europa.eu/x')

        expect { with_classifications(insecure).validate! }.to refusing('R-EDM-REQ-C101')
      end

      # The assertion reads `sdg:ValueExpression/text()` raw, where `C100`
      # normalises: a blank in front satisfies the one and breaks the other.
      it 'refuses an expression opening on a blank, under R-EDM-REQ-C101' do
        padded = classification(expression: ' https://query.cs.oots.tech.ec.europa.eu/x')

        expect { with_classifications(padded).validate! }.to refusing('R-EDM-REQ-C101')
      end

      # `lower-case` is applied before the comparison, so the scheme may be
      # written in any case at all.
      it 'accepts an expression whose scheme is in upper case' do
        shouted = classification(expression: 'HTTPS://query.cs.oots.tech.ec.europa.eu/x')

        expect(with_classifications(shouted).validate!).to be_truthy
      end

      # What the published example carries: the URL, then a newline and the
      # indentation of the snippet. Nothing follows the scheme's business.
      it 'accepts the expression the published example carries, newline and all' do
        wrapped = classification(expression: "#{value_expression}\n      ")

        expect(with_classifications(wrapped).validate!).to be_truthy
      end
    end

    # `R-EDM-REQ-C022` on the `sdg:Description` and `C021` on its `@lang`: the
    # attribute absent or blank under the first, outside the code list under the
    # second. The pair `require_language` already reads for an agent's name and
    # a requirement's wordings.
    describe 'the language its description names' do
      it 'refuses a description carrying no lang at all, under R-EDM-REQ-C022' do
        described = classification(descriptions: '<sdg:Description>Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C022')
      end

      # Written empty, the attribute is there and the first rule normalises it:
      # the empty string is no more a language than no attribute at all.
      it 'refuses a lang written empty, under R-EDM-REQ-C022' do
        described = classification(descriptions: '<sdg:Description lang="">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C022')
      end

      it 'refuses a code the list does not publish, under R-EDM-REQ-C021' do
        described = classification(descriptions: '<sdg:Description lang="ZZ">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # The comparison carries no `i` flag, and the list publishes upper case.
      it 'refuses a published code written in lower case' do
        described = classification(descriptions: '<sdg:Description lang="en">French municipality</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # `InformationConceptType` makes `sdg:Description` `0..n`, and each
      # attribute is a context of its own: the second is judged as the first is.
      it 'judges a second description as much as the first' do
        described = classification(descriptions: '<sdg:Description lang="EN">French municipality</sdg:Description>' \
                                                 '<sdg:Description lang="fr">Commune</sdg:Description>')

        expect { with_classifications(described).validate! }.to refusing('R-EDM-REQ-C021')
      end

      # Nothing requires a description: the contexts of both rules are the
      # element and its attribute, and `InformationConceptType` numbers it
      # `0..n`.
      it 'accepts a classification describing itself in no language at all' do
        expect(with_classifications(classification(descriptions: '')).validate!).to be_truthy
      end
    end

    # The Schematron of 1.2.5 publishes these assertions word for word, so
    # nothing of the version read modulates them — unlike `S022` and `S061`,
    # which `EdmSpecification` tells apart. A correspondent still on that line
    # is refused under the same identifier.
    it 'judges a classification of the 1.2 line by the very same rule' do
      earlier = earlier_line_envelope do |body|
        body.sub('<rim:Slot name="EvidenceRequester">') { classification_slot(classification(id: 'FR-MUNICIPALITY')) }
      end

      expect(earlier.specification).to eq(EdmSpecification::V1_2)
      expect { received(earlier).validate! }.to refusing('R-EDM-REQ-C019')
    end
  end
end
