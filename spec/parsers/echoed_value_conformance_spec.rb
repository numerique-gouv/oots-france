require 'rails_helper'

RSpec.describe EchoedValueConformance do
  subject(:request) { received(RetrievedMessageParser.new(real_envelope('requete'))) }

  def received(message) = judged(message)

  describe 'a request reduced to what the family judges' do
    def reduced(classification)
      evidence_type = "<sdg:DataServiceEvidenceType><sdg:EvidenceTypeClassification>#{classification}" \
                      '</sdg:EvidenceTypeClassification><sdg:Title lang="EN">Proof of birth</sdg:Title>' \
                      '</sdg:DataServiceEvidenceType>'

      described_class.new(query_request(
        "<query:Query><rim:Slot name=\"EvidenceRequest\"><rim:SlotValue>#{evidence_type}</rim:SlotValue></rim:Slot></query:Query>"
      ), specification: EdmSpecification::V2_0)
    end

    it 'accepts an evidence type the Semantic Repository classifies' do
      expect(reduced('https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e').validate!)
        .to be_a(described_class)
    end

    it 'refuses one it does not, under R-EDM-REQ-C027' do
      expect { reduced('https://example.org/types/abc').validate! }.to refusing('R-EDM-REQ-C027')
    end
  end

  # `R-EDM-REQ-C041` and `C042`, whose context is the identifier itself: a
  # request naming no identifier for its beneficiary breaks neither, chapter 2.1
  # §2.3.1.2 providing for an identity established in the requester's own
  # country. Refused by `validate!` — the answer describes no evidence subject.
  describe 'the scheme of the beneficiary identifier' do
    it 'accepts a request carrying no identifier at all' do
      expect(request.validate!).to be(request)
    end

    it 'accepts one under the fixed value the rule names' do
      expect(with_beneficiary_identifier(' schemeID="eidas"').validate!).to be_a(described_class)
    end

    it 'refuses one naming no scheme, under R-EDM-REQ-C041' do
      expect { with_beneficiary_identifier('').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C041')))
    end

    # `C041` asserts the attribute's presence and nothing more, so an empty one
    # satisfies it and falls to `C042`, which compares the value: the refusal
    # names the rule that actually broke.
    it 'refuses one whose scheme is present and empty, under R-EDM-REQ-C042' do
      expect { with_beneficiary_identifier(' schemeID=""').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end

    # The message of `C042` says `eidas2` « can be used for testing purposes
    # until confirmation of provision of a suitable legal basis », and its
    # assertion admits nothing but `eidas`. France follows the assertion.
    it 'refuses eidas2, which the message admits and the assertion does not' do
      expect { with_beneficiary_identifier(' schemeID="eidas2"').validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end

    # The rule fires per element, and the schema admits several: a reader that
    # judged only the first would serve a request the rule refuses.
    it 'refuses a second identifier the first one made look conformant' do
      several = with_beneficiary_identifier(' schemeID="eidas"') do |identifier|
        "#{identifier}<sdg:Identifier schemeID=\"eidas2\">FR/DE/A2635542Y</sdg:Identifier>"
      end

      expect { several.validate! }
        .to raise_error(an_instance_of(UnreadableMessageError).and(having_attributes(detail: 'R-EDM-REQ-C042')))
    end
  end

  # The three values `app/templates/evidence_response.v2_0.xml.erb` copies out
  # of the request into the answer France signs. Each is judged at the read by
  # the request rule that judges it, because a FATAL response rule judges it
  # again on the way out: answering a request that broke one would have France
  # sign a message breaking the other.
  describe 'the values the answer echoes' do
    # `R-EDM-REQ-C027` (FATAL), whose twin `R-EDM-RESP-C017` asserts the very
    # same expression over the `sdg:IsConformantTo` of the response.
    describe 'the classification of the evidence type' do
      it 'accepts the one the real request carries' do
        expect(request.validate!).to be(request)
      end

      it 'refuses a URL that is not the Semantic Repository, under R-EDM-REQ-C027' do
        expect { classified_as('https://example.org/types/abc').validate! }.to refusing('R-EDM-REQ-C027')
      end

      # `R-EDM-REQ-C115` judges the same element without the midfix and under
      # `CAUTION`, so an acceptance URL is refused by nothing.
      it 'accepts an environment midfix, C115 alone objecting and only as a caution' do
        acceptance = 'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/' \
                     'oots/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'

        expect(classified_as(acceptance).validate!).to be_a(described_class)
      end

      # The alternation of the rule adds `oots` to the country codes, « for
      # testing purposes and agreed OOTS data models ».
      it 'accepts oots where a country code would sit' do
        expect(classified_as(classification_for('oots')).validate!).to be_a(described_class)
      end

      it 'refuses a country the OOTS_Country code list does not publish' do
        expect { classified_as(classification_for('ZZ')).validate! }.to refusing('R-EDM-REQ-C027')
      end

      # The assertion carries no `i` flag, where `R-EDM-REQ-C019` on a provider
      # classification does: the hexadecimal is lower case or it is refused.
      it 'refuses a UUID written in upper case, the rule being case-sensitive' do
        expect { classified_as(classification_for('DE', uuid: 'CA8AFED6-2DC0-422A-A931-D21C3D8D370E')).validate! }
          .to refusing('R-EDM-REQ-C027')
      end

      # The assertion applies no `normalize-space` before matching, where
      # `R-EDM-REQ-C008` on a requirement identifier does: the two are read as
      # they are written, and this one refuses what it would otherwise trim.
      it 'refuses one padded with blanks, this assertion normalising nothing' do
        expect { classified_as(" #{classification_for('DE')} ").validate! }.to refusing('R-EDM-REQ-C027')
      end
    end

    # `R-EDM-REQ-C029` and `C028` (FATAL), the pair `R-EDM-RESP-C018` reads
    # again over the titles the response copies out.
    describe 'the language of the evidence type titles' do
      it 'refuses a title carrying no lang at all, under R-EDM-REQ-C029' do
        expect { titled('<sdg:Title>Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C029')
      end

      it 'refuses one whose lang is present and blank, under the same rule' do
        expect { titled('<sdg:Title lang="  ">Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C029')
      end

      it 'refuses a code the LanguageCode list does not publish, under R-EDM-REQ-C028' do
        expect { titled('<sdg:Title lang="xx">Certificate of Birth</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C028')
      end

      # The list publishes upper case and the assertion compares exactly, with
      # no `i` flag: a correspondent writing `fr` breaks a FATAL rule.
      it 'refuses a lower-case code, the comparison being exact' do
        expect { titled('<sdg:Title lang="fr">Acte de naissance</sdg:Title>').validate! }
          .to refusing('R-EDM-REQ-C028')
      end

      it 'accepts the same code in upper case' do
        expect(titled('<sdg:Title lang="FR">Acte de naissance</sdg:Title>').validate!).to be_a(described_class)
      end

      # The context of both rules is the title and its attribute, and the schema
      # admits `1..n`: a reader judging the first alone would serve a request a
      # FATAL rule refuses.
      it 'refuses a second title the first one made look conformant' do
        several = titled('<sdg:Title lang="EN">Certificate of Birth</sdg:Title>',
          '<sdg:Title lang="xx">Acte de naissance</sdg:Title>')

        expect { several.validate! }.to refusing('R-EDM-REQ-C028')
      end
    end

    # No assertion counts the titles — `R-EDM-RESP-S030` bounds the children of
    # `sdg:IsConformantTo` without requiring one — so the floor is the table of
    # chapter 4.5.1 §3.5 and the XSD, and the refusal names them rather than a
    # rule that does not exist.
    describe 'an evidence type carrying no title at all' do
      it 'refuses it under the chapter, which is what gives Title 1..n' do
        expect { titled.validate! }
          .to raise_error(an_instance_of(UnreadableMessageError)
            .and(having_attributes(detail: a_string_starting_with('TDD 4.5.1 §3.5'))))
      end
    end

    # `R-EDM-REQ-C040` and `C051` (FATAL), whose twins `R-EDM-RESP-C028` and
    # `C035` judge the identifier the response copies under `sdg:IsAbout`.
    describe 'the country codes of the eIDAS identifier' do
      it 'accepts a request carrying no identifier at all, the context being the element' do
        expect(request.validate!).to be(request)
      end

      it 'refuses a country the OOTS_Country list does not publish, under R-EDM-REQ-C040' do
        expect { identified_as('ZZ/FR/02635542Y').validate! }.to refusing('R-EDM-REQ-C040')
      end

      it 'refuses one whose second code is unknown just as much as its first' do
        expect { identified_as('FR/ZZ/02635542Y').validate! }.to refusing('R-EDM-REQ-C040')
      end

      # The assertion carries the `i` flag, so lower case is conformant and
      # refusing it would cost an exchange the specification admits.
      it 'accepts codes written in lower case, the rule being case-insensitive' do
        expect(identified_as('es/at/02635542Y').validate!).to be_a(described_class)
      end

      it 'refuses the same unknown country on a legal person, under R-EDM-REQ-C051' do
        expect { about_an_organisation('DE/QQ/123456789').validate! }.to refusing('R-EDM-REQ-C051')
      end

      it 'accepts the identifier the organisation of the suite carries' do
        expect(about_an_organisation('FR/DE/A2635542Y').validate!).to be_a(described_class)
      end
    end

    # The classification of the real request, its country segment replaced:
    # everything else is what the correspondent actually sent.
    def classification_for(country, uuid: 'ca8afed6-2dc0-422a-a931-d21c3d8d370e')
      "https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/#{country}/#{uuid}"
    end

    def classified_as(value)
      with_body do |body|
        body.sub(/(<sdg:EvidenceTypeClassification>)[^<]*/) { "#{Regexp.last_match(1)}#{value}" }
      end
    end

    # Every title of the request at once, and not the first of them: the one a
    # real gateway delivered carries two, `FR` and `EN`. No title at all when
    # called with none — what the floor of chapter 4.5.1 §3.5 refuses.
    def titled(*titles)
      with_body { |body| body.sub(%r{<sdg:Title .*</sdg:Title>}m) { titles.join } }
    end

    # The real request carries no eIDAS identifier for its natural person:
    # `with_beneficiary_identifier` adds one under the scheme `C040`'s context
    # requires, and its block is where the value is chosen.
    def identified_as(identifier)
      with_beneficiary_identifier(' schemeID="eidas"') { |added| added.sub('FR/DE/A2635542Y', identifier) }
    end

    def about_an_organisation(identifier)
      received(envelope_about_an_organisation(legal_person_slot.sub('FR/DE/A2635542Y', identifier)))
    end
  end
end
