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
end
