require 'rails_helper'

# Read against a real Finnish entry captured on the acceptance environment: it
# is the one whose access service declares `oots-edm:v2.0`.
RSpec.describe DataServicesResponseParser do
  subject(:providers) { described_class.new(body).providers }

  let(:body) { common_services_answer('dsd_data_services_fi').first }

  it 'reads the provider the directory holds for that evidence type' do
    expect(providers.size).to eq(1)
  end

  # The two are different values in the same entry, and conflating them would
  # address the message to the gateway as if it were the organisation.
  it 'tells the publisher apart from the access service carrying messages to it' do
    expect(providers.first.ebms_identity)
      .to eq(EbmsIdentity.new(id: 'FIKEHA02', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FI'))
    expect(providers.first.access_point)
      .to have_attributes(id: 'AP_FI_03', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FI')
  end

  it 'names the provider in each language the directory publishes' do
    expect(providers.first.descriptions).to include('EN' => 'Keha v. 2.0')
  end

  # Left to its default the address would be French, which would put the wrong
  # country in a message addressed to Finland.
  it 'reads the country from the publisher rather than defaulting to ours' do
    expect(providers.first.address.country).to eq('FI')
  end

  # Refused at construction and not when `providers` is first asked for: it is
  # on the strength of having built one of these that a caller caches the body
  # it was built from.
  it 'refuses an access service the directory published without a scheme' do
    stripped = body.sub(/schemeID="[^"]*"/, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /annoncé par l'annuaire/)
  end

  # One nesting level below the record: the slot is there, its access services
  # are not. Empty is not an answer a directory gives by succeeding.
  it 'refuses a data service carrying no access service' do
    stripped = body.gsub(%r{<sdg:AccessService>.*</sdg:AccessService>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # An outgoing request adopts most of this into its `DataServiceEvidenceType`
  # slot, so what the directory says of the pairing is read and not only what
  # leads to a provider. The level of assurance is among what chapter 4.5.1 has
  # a request omit; it is read for the console, which shows it.
  it 'reads what the directory says about the service itself' do
    service = described_class.new(body).data_services.first

    expect(service).to have_attributes(
      id: '41170824-15d9-4c16-984e-63b75b937b8c',
      evidence_type_classification:
        'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74',
      distribution_format: 'application/pdf',
      distribution_language: 'EN',
      level_of_assurance: 'Substantial',
    )
    expect(service.descriptions).to include('FI' => 'Testi-PDF')
    expect(service.details).to include('FI' => 'Testitodistetyyppi testivaatimukselle')
  end

  # Optional in the directory as in a request: absent, the evidence comes back
  # in any of the available languages.
  it 'leaves the language nil where the directory published none' do
    stripped = body.sub(%r{<sdg:Language>.*?</sdg:Language>}m, '')

    expect(described_class.new(stripped).data_services.first.distribution_language).to be_nil
  end

  # Chapter 4.5.1 has the request carry the data model back: without it a
  # correspondent asked for XML does not know which model to produce it against.
  # R-DSD-RESP-C039 and C041 are what oblige the directory to publish one.
  it 'reads the data model the directory publishes for the distribution' do
    model = 'https://sr.acc.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40'
    published = body.sub('</sdg:DistributedAs>', "<sdg:ConformsTo>#{model}</sdg:ConformsTo></sdg:DistributedAs>")

    expect(described_class.new(published).data_services.first.distribution_conforms_to).to eq(model)
  end

  it 'leaves the data model nil where the directory published none' do
    expect(described_class.new(body).data_services.first.distribution_conforms_to).to be_nil
  end

  # A directory publishes one distribution per format — C039 and C041 are
  # written around that — and the three elements must be read from one and the
  # same: paths anchored on the record would take the format of the first and
  # the data model of another, and pair a PDF with an XML schema in a request
  # nothing downstream would question. Asking for several is OOTS-129's.
  it 'reads the format and the data model from one and the same distribution' do
    published = body.sub('</sdg:DistributedAs>', <<~XML.strip)
      </sdg:DistributedAs>
      <sdg:DistributedAs>
        <sdg:Format>application/xml</sdg:Format>
        <sdg:Language>FI</sdg:Language>
        <sdg:ConformsTo>https://sr.acc.oots.tech.ec.europa.eu/datamodels/SDG-CertificateOfBirth</sdg:ConformsTo>
      </sdg:DistributedAs>
    XML

    expect(described_class.new(published).data_services.first)
      .to have_attributes(distribution_format: 'application/pdf', distribution_language: 'EN',
        distribution_conforms_to: nil)
  end

  # The versions a gateway declares are what the `specification` parameter of
  # the query filters on: a service missing from an answer may exist and speak
  # another version, which nothing else would tell an operator.
  it 'reads the EDM versions the access service declares' do
    expect(providers.first.access_point.conforms_to).to eq(['oots-edm:v2.0'])
    expect(providers.first.access_point.descriptions).to eq('EN' => 'Finland OOTS DEV TDD 2.0.0')
  end

  # The Finnish capture publishes its country and nothing else, so the three
  # postal elements are read from an answer built here — the only way to prove
  # the paths that read them are the right ones.
  it 'reads the postal lines the directory publishes' do
    posted = body.sub('<sdg:AdminUnitLevel1>FI</sdg:AdminUnitLevel1>', <<~XML.strip)
      <sdg:PostCode>50101</sdg:PostCode>
      <sdg:PostCityName>Mikkeli</sdg:PostCityName>
      <sdg:Thoroughfare>PL 1000</sdg:Thoroughfare>
      <sdg:AdminUnitLevel1>FI</sdg:AdminUnitLevel1>
    XML

    address = described_class.new(posted).providers.first.address

    expect(address.postal_lines).to eq(['PL 1000', '50101 Mikkeli'])
    expect(address.country).to eq('FI')
  end

  it 'refuses a publisher the directory published without an address' do
    stripped = body.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /adresse du fournisseur/)
  end

  # `DSD:ERR:0005` is the one code of chapter 3.1.4 that refuses nothing: the
  # country holds several providers for this evidence type and asks the user to
  # narrow it down. Fabricated, acceptance publishing no such country.
  describe 'when the directory asks the user to narrow the choice down' do
    subject(:questions) { asked(data_services_asking_the_user).classifications }

    # The answer is read by building the parser, and it is by raising that the
    # parser hands the questions back — so the error is caught here once, and
    # each example reads what it carries.
    def asked(body)
      described_class.new(body)
      raise 'the directory refused instead of asking'
    rescue UserAttributesRequired => e
      e
    end

    it 'raises an error of its own rather than the refusal the other codes give' do
      expect { described_class.new(data_services_asking_the_user) }
        .to raise_error(UserAttributesRequired, /DSD:ERR:0005/)
    end

    it 'keeps the code, which is what tells this apart from a refusal' do
      expect(asked(data_services_asking_the_user).code).to eq('DSD:ERR:0005')
    end

    it 'reads the question the directory published, in full' do
      expect(questions.sole).to have_attributes(
        id: '5b8b7dbc-64e6-4b4b-9b40-fc0eb0e6a67b',
        scheme_id: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
        type: 'codelist',
        value_expression: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
      )
      expect(questions.sole.descriptions).to eq('EN' => 'In which town were you born?')
    end

    # `R-DSD-ERR-C033` matches the scheme on `normalize-space`: one the
    # directory padded satisfies the rule, and would be refused here if it
    # were stored as written.
    it 'strips a scheme the directory published with padding' do
      padded = data_services_asking_the_user(
        concepts: [classification_concept(scheme_id: '  https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth ')],
      )
      read = asked(padded).classifications.sole

      expect(read.scheme_id).to eq('https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth')
      expect(read).to be_valid
    end

    # `R-DSD-ERR-S027` makes the slot a Set, whose order is nonetheless the one
    # the directory wrote: a caller putting two questions to its user puts them
    # in the order they were asked.
    it 'reads every concept the slot carries, in the order published' do
      insured = classification_concept(
        id: '2c4a2a6f-9f2e-4f4b-8bb4-1f6b0c2f3a11', type: 'boolean', scheme_id: nil,
        value_expression: nil, descriptions: { 'EN' => 'Are you privately insured?' },
      )
      read = asked(data_services_asking_the_user(concepts: [classification_concept, insured])).classifications

      expect(read.map(&:label)).to eq(['In which town were you born?', 'Are you privately insured?'])
      expect(read.last).to have_attributes(type: 'boolean', scheme_id: nil, value_expression: nil)
    end

    # The three `DSD-ERR005` examples of the 2.0.1 corpus
    # (`schematron-validator/…/DSD-ERR/valid/`) write `Codelist`, which
    # `R-DSD-ERR-C031` refuses: read strictly, the documents the specification
    # files under `valid/` would be unreadable.
    it 'reads a type the published examples capitalise' do
      capitalised = data_services_asking_the_user(concepts: [classification_concept(type: 'Codelist')])

      expect(asked(capitalised).classifications.sole).to have_attributes(type: 'codelist', codelist?: true)
    end

    # Kept as published rather than dropped: the concept is then invalid, and
    # says which type it was given, where a nil would say only that nothing was
    # read.
    it 'keeps a type the rules do not publish, and holds the concept invalid' do
      unknown = data_services_asking_the_user(concepts: [classification_concept(type: 'date')])
      read = asked(unknown).classifications.sole

      expect(read.type).to eq('date')
      expect(read).not_to be_valid
    end

    # `R-DSD-ERR-S010` admits two slots and no others, but two of the three
    # `DSD-ERR005` examples of the 2.0.1 corpus carry a third — and they sit
    # under `valid/`, beside the rules they break. Refusing it would refuse
    # what the specification publishes as its own model.
    it 'ignores a slot the rules do not admit' do
      extra = data_services_asking_the_user(extra_slots: <<~XML)
        <rim:Slot name="JurisdictionDetermination">
          <rim:SlotValue xsi:type="rim:StringValueType"><rim:Value>FI</rim:Value></rim:SlotValue>
        </rim:Slot>
      XML

      expect(asked(extra).classifications.size).to eq(1)
    end

    # Kept as published rather than dropped, for the same reason as above: the
    # concept says which type it was given, and is invalid for it.
    it 'keeps a concept the directory published without a type' do
      untyped = data_services_asking_the_user(concepts: [classification_concept(type: nil)])
      read = asked(untyped).classifications.sole

      expect(read.type).to be_nil
      expect(read).not_to be_valid
    end

    # `R-DSD-ERR-S022` makes the slot mandatory, so its absence is a directory
    # breaking its own rule. Nothing is left to ask the user, and the code is
    # then said as the ordinary refusal it has become — not as an unreadable
    # message, which is what the shared slot reader would have raised.
    it 'falls back to the ordinary refusal where the question is missing' do
      silent = data_services_asking_the_user.sub(%r{<rim:Slot name="UserRequested.*?</rim:Slot>}m, '')

      expect { described_class.new(silent) }.to raise_error(CommonServicesError, /DSD:ERR:0005/) do |raised|
        expect(raised).not_to be_a(UserAttributesRequired)
      end
    end

    # The slot is there and empty — `R-DSD-ERR-S024` wants at least one
    # element — which reaches the same fallback by the other route.
    it 'falls back to the ordinary refusal where the slot carries no question' do
      empty = data_services_asking_the_user(concepts: [])

      expect { described_class.new(empty) }.to raise_error(CommonServicesError, /DSD:ERR:0005/) do |raised|
        expect(raised).not_to be_a(UserAttributesRequired)
      end
    end

    # `R-DSD-ERR-S019` puts a concept in every element. One element without
    # its concept would otherwise yield the other questions and nothing to say
    # one was lost — a questionnaire with a hole the caller cannot see, whose
    # answers would be reissued only to be refused again. So the whole set
    # gives way, and the answer is the ordinary refusal.
    it 'gives up the whole set rather than asking part of it' do
      amputated = data_services_asking_the_user(
        concepts: [classification_concept, '<rim:Element xsi:type="rim:AnyValueType"/>'],
      )

      expect { described_class.new(amputated) }.to raise_error(CommonServicesError, /DSD:ERR:0005/) do |raised|
        expect(raised).not_to be_a(UserAttributesRequired)
      end
    end
  end

  # CA4 of OOTS-50: the five other codes keep exactly the behaviour they had.
  it 'leaves the other codes of the chapter as the refusals they are' do
    expect { described_class.new(common_services_answer('dsd_aucun_service_fr').first) }
      .to raise_error(CommonServicesError, /DSD:ERR:0001/) do |raised|
        expect(raised).not_to be_a(UserAttributesRequired)
      end
  end
end
