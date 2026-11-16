require 'rails_helper'

# Read against a real Finnish entry captured on the acceptance environment: it
# is the one whose access service declares `oots-edm:v2.0`.
RSpec.describe DataServicesResponseParser do
  subject(:providers) { described_class.new(body).providers }

  let(:body) { common_services_answer('dsd_data_services_fi').first }
  let(:data_model) { 'https://sr.acc.oots.tech.ec.europa.eu/datamodels/SDG-CertificateOfBirth' }

  def service_distributed_as(*distributions)
    body.sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m, distributions.join)
  end

  def distribution(format, language: nil, conforms_to: nil)
    "<sdg:DistributedAs><sdg:Format>#{format}</sdg:Format>" \
      "#{"<sdg:Language>#{language}</sdg:Language>" if language}" \
      "#{"<sdg:ConformsTo>#{conforms_to}</sdg:ConformsTo>" if conforms_to}</sdg:DistributedAs>"
  end

  def requested(published) = described_class.new(published).data_services.first

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

  # The public page of available evidence lists them all; a request asks for
  # the PDF, published last.
  it 'reads the format of every distribution, and requests the PDF wherever it stands' do
    service = requested(common_services_answer('dsd_data_services_at_cb10c17a').first)

    expect(service.distribution_formats).to eq(%w[application/json application/xml application/pdf])
    expect(service.distribution_format).to eq('application/pdf')
  end

  # The acceptance directory returns the French student status JSON first,
  # whatever order it was entered in: the order decides nothing once a PDF is
  # published.
  describe 'the French student status, distributed as JSON then PDF' do
    let(:body) { common_services_answer('dsd_data_services_fr_1e4a95b7').first }

    it 'requests the PDF, without a data model' do
      expect(requested(body)).to have_attributes(distribution_format: 'application/pdf',
        distribution_conforms_to: nil, distribution_formats: %w[application/json application/pdf])
    end

    it 'requests the same distribution with the two swapped' do
      json, pdf = body.scan(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m)

      expect(requested(service_distributed_as(pdf, json)))
        .to have_attributes(distribution_format: 'application/pdf', distribution_conforms_to: nil)
    end
  end

  # The console shows them all, each read whole and in the directory's order.
  it 'reads every distribution, each from its own element' do
    published = service_distributed_as(distribution('application/xml', language: 'FI', conforms_to: data_model),
      distribution('application/pdf', language: 'EN'))

    expect(requested(published).distributions.map(&:attributes)).to eq([
      { 'format' => 'application/xml', 'language' => 'FI', 'conforms_to' => data_model },
      { 'format' => 'application/pdf', 'language' => 'EN', 'conforms_to' => nil },
    ])
  end

  # Between two images no criterion exists, and the order decides.
  it 'requests the first image where no PDF is published' do
    expect(requested(service_distributed_as(distribution('application/json'), distribution('image/png'),
      distribution('image/jpeg'))).distribution_format).to eq('image/png')
  end

  # Nothing unstructured is published: the first, with its own data model.
  it 'requests the first structured distribution where no unstructured one is published' do
    expect(requested(service_distributed_as(distribution('application/xml', conforms_to: data_model),
      distribution('application/json'))))
      .to have_attributes(distribution_format: 'application/xml', distribution_conforms_to: data_model)
  end

  # `image/jpg` is no code of the `OOTSMediaTypes` list, so it is not the
  # human-readable distribution chapter 4.5.1 §3.5 speaks of.
  it 'does not count a format the code list does not carry as unstructured' do
    expect(requested(service_distributed_as(distribution('application/xml'), distribution('image/jpg')))
      .distribution_format).to eq('application/xml')
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
    )
  end

  # Asserted on the capture and not left to the model's default, which would
  # answer the same whether the parser looked or not.
  it 'says the capture does publish one' do
    expect(described_class.new(body).data_services.first.distribution_published).to be(true)
  end

  # Chapter 4.5.1 §3.5 has only « distributions which the data service is able
  # to provide » requested: paths anchored on the record would take the
  # language and the data model of the XML published first, and pair a PDF
  # with an XML schema in a request nothing downstream would question.
  it 'reads the format, the language and the data model from the requested distribution alone' do
    published = service_distributed_as(distribution('application/xml', language: 'FI', conforms_to: data_model),
      distribution('application/pdf', language: 'EN'))

    expect(requested(published))
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

  # Captured on the acceptance environment for the Greek evidence type the
  # directory asks a question about: `DSD:ERR:0005`, then the answer to the same
  # query carrying `TC03`.
  describe 'a question about the provider' do
    let(:asked) { common_services_answer('dsd_classification_requise_el_8b3b6a31').first }
    let(:answered) { common_services_answer('dsd_data_services_el_8b3b6a31_tc03').first }

    def refusal(body)
      described_class.new(body)
    rescue CommonServicesError => e
      e
    end

    it 'refuses with the question the exception asks, read whole' do
      expect(refusal(asked)).to have_attributes(code: 'DSD:ERR:0005', classifications: [
        EvidenceProviderClassification.new(
          id: '1254f10f-406e-4f28-b1ba-d107b93fa264',
          scheme_id: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases',
          type: 'codelist',
          value_expression: 'https://query.cs.acc.oots.tech.ec.europa.eu/codelists/EL/ProjectathonTestCases/8b3b6a31-9b62-48d7-8926-997df4f91bb5',
          descriptions: { 'EN' => 'Projectathon test case', 'EL' => 'Σενάριο Projectathon' },
        ),
      ])
    end

    # `R-DSD-ERR-S022` makes the slot mandatory; a directory leaving it out asks
    # nothing anybody could answer.
    it 'asks nothing of a refusal carrying no classification' do
      stripped = asked.sub(%r{<rim:Slot name="UserRequestedClassificationConcepts">.*?</rim:Slot>}m, '')

      expect(refusal(stripped).classifications).to be_empty
    end

    it 'reads no question off another refusal' do
      expect(refusal(asked.sub('DSD:ERR:0005', 'DSD:ERR:0006')).classifications).to be_empty
    end

    it 'gives the service matched the classification and the value it supports' do
      service = described_class.new(answered).data_services.first

      expect(service.classifications.map { |found| [found.id, found.supported_value] })
        .to eq([%w[1254f10f-406e-4f28-b1ba-d107b93fa264 TC03]])
    end
  end
end
