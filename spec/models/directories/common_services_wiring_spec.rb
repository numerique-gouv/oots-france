require 'rails_helper'

# The one spec that builds the real object graph — no double anywhere below the
# HTTP boundary. Every other spec of this chain injects a collaborator, which is
# what makes each layer testable and, taken together, leaves the wiring itself
# unchecked: a swapped country between the two chained Evidence Broker calls, a
# wrong default class, an argument in the wrong order, all satisfy the doubles.
#
# The end-to-end scenarios would have caught it, and they are suspended until
# France is registered — see `docs/test_e2e.md`. This stands in their place for
# what can be checked without a gateway.
RSpec.describe 'Le câblage des annuaires centraux' do
  subject(:directory) { Directories::CommonServices.new }

  let(:base) { 'https://query.cs.acc.oots.tech.ec.europa.eu' }
  let(:requirement) { 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000' }

  before do
    allow(CommonServicesInstance).to receive(:new) do |service|
      instance_double(CommonServicesInstance, base_url: "#{base}/#{service}/")
    end

    stub_directory("#{base}/eb/rest/search", 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory("#{base}/eb/rest/search", 'evidence-types-by-requirement', 'eb_evidence_types_fr')
    stub_directory("#{base}/dsd/rest/search", 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  # Only the DNS is doubled: the signature of each answer is verified for real,
  # against the trust store the deployment carries.
  def stub_directory(url, query_fragment, fixture)
    body, headers = common_services_answer(fixture)

    stub_request(:get, url).with(query: hash_including('queryId' => a_string_including(query_fragment)))
      .to_return(body:, headers:)
  end

  it 'enchaîne les deux requêtes de l\'Evidence Broker jusqu\'au type de justificatif' do
    types = directory.evidence_types_for_procedure('00', 'FR')

    expect(types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])
  end

  # The procedure is ours, the evidence types are the asked country's: swapping
  # the two is the wiring mistake the doubles cannot see.
  it 'lit les exigences chez nous et les types dans le pays interrogé' do
    directory.evidence_types_for_procedure('00', 'FI')

    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('procedure-id' => '00', 'country-code' => 'FR'))).to have_been_made
    expect(a_request(:get, "#{base}/eb/rest/search")
      .with(query: hash_including('requirement-id' => requirement, 'country-code' => 'FI'))).to have_been_made
  end

  it 'résout le fournisseur et son point d\'accès par le Data Service Directory' do
    provider = directory.providers('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI').first

    expect(provider.ebms_identity.id).to eq('FIKEHA02')
    expect(provider.access_point.id).to eq('AP_FI_03')
  end

  it 'restreint la recherche de fournisseur à la version que nous produisons' do
    directory.providers('https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/x', 'FI')

    expect(a_request(:get, "#{base}/dsd/rest/search")
      .with(query: hash_including('specification' => EdmSpecification::IDENTIFIER))).to have_been_made
  end

  # The chain reports a refusal as the named exception the interactors handle,
  # rather than letting a `CommonServicesError` reach the caller unchanged.
  it 'traduit le refus de l\'annuaire en l\'exception que les interacteurs attendent' do
    stub_directory("#{base}/dsd/rest/search", 'dataservices-by-evidencetype', 'dsd_aucun_service_fr')

    expect { directory.providers('https://sr.acc.oots.tech.ec.europa.eu/x', 'FR') }
      .to raise_error(CountryCodeNotFound, /FR/)
  end
end
