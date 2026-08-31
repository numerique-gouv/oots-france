require 'rails_helper'

# Read against a real Finnish entry captured on the acceptance environment: it
# is the one whose access service declares `oots-edm:v2.0`.
RSpec.describe DataServicesResponseParser do
  subject(:providers) { described_class.new(body).providers }

  let(:body) { common_services_answer('dsd_data_services_fi').first }
  # The capture distributes a PDF, which C039 and C041 do not judge: only a
  # structured format puts a record under them.
  let(:structured) do
    body.sub('<sdg:Format>application/pdf</sdg:Format>', '<sdg:Format>application/xml</sdg:Format>')
  end

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

  # R-DSD-RESP-S027 (FATAL) makes `sdg:DistributedAs` mandatory, so a record
  # published without one is the directory departing from the specification.
  # Read here and nowhere else: nil answers for an absent element as for an
  # empty one, and only the answer says which.
  it 'says when the directory published no distribution at all' do
    stripped = body.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m, '')

    expect(described_class.new(stripped).data_services.first).to have_attributes(
      distribution_published: false, distribution_format: nil,
      distribution_language: nil, distribution_conforms_to: nil,
      unstructured_sibling_published: false,
    )
  end

  # Asserted on the capture and not left to the model's default, which would
  # answer the same whether the parser looked or not.
  it 'says the capture does publish one' do
    expect(described_class.new(body).data_services.first.distribution_published).to be(true)
  end

  # C039 and C041 excuse a structured distribution from carrying a data model
  # when an unstructured one is published beside it, so the absence of the value
  # is two different things and only the record says which.
  it 'says when an unstructured distribution is published beside a structured one' do
    published = structured.sub('</sdg:DistributedAs>', <<~XML.strip)
      </sdg:DistributedAs>
      <sdg:DistributedAs><sdg:Format>application/pdf</sdg:Format></sdg:DistributedAs>
    XML

    expect(described_class.new(published).data_services.first)
      .to have_attributes(distribution_format: 'application/xml', unstructured_sibling_published: true)
  end

  it 'says when a structured distribution is published on its own' do
    expect(described_class.new(structured).data_services.first)
      .to have_attributes(distribution_format: 'application/xml', unstructured_sibling_published: false)
  end

  # The diagnostic text of C039 and C041 also names `image/jpg`, which the code list has
  # no code for; both assertions test membership of the list, so a distribution
  # published under that spelling excuses nothing.
  it 'excuses nothing for a format the code list does not carry' do
    published = structured.sub('</sdg:DistributedAs>', <<~XML.strip)
      </sdg:DistributedAs>
      <sdg:DistributedAs><sdg:Format>image/jpg</sdg:Format></sdg:DistributedAs>
    XML

    expect(described_class.new(published).data_services.first.unstructured_sibling_published).to be(false)
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
end
