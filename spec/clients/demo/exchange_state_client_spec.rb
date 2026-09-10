require 'rails_helper'

RSpec.describe Demo::ExchangeStateClient do
  subject(:client) { described_class.new }

  let(:exchange_id) { 'aaaaaaaa-0000-4000-8000-000000000001' }

  # Over HTTP and through the published contract: the procedure holds no
  # privilege over the deployment it calls, and this is the address
  # `docs/oots_context.md` gives a French service provider.
  it 'reads the state at GET /requete/:exchange_id' do
    stub_request(:get, "#{Settings.oots_france_url}/requete/#{exchange_id}")
      .to_return(body: { statut: 'failed', codeErreur: 'EDM:ERR:0004' }.to_json,
        headers: { 'Content-Type' => 'application/json' })

    answer = client.fetch(exchange_id)

    expect(answer.exchange_status).to eq('failed')
    expect(answer.edm_error_code).to eq('EDM:ERR:0004')
  end

  # A refusal is an answer to a service provider, so no `raise_error`
  # middleware: the page has to show the status and the message it carried.
  it 'returns the refusal rather than raising on it' do
    stub_request(:get, "#{Settings.oots_france_url}/requete/#{exchange_id}")
      .to_return(status: 404, body: { erreur: 'Échange inconnu' }.to_json,
        headers: { 'Content-Type' => 'application/json' })

    answer = client.fetch(exchange_id)

    expect(answer.status).to eq(404)
    expect(answer.error).to eq('Échange inconnu')
  end

  it 'reads a body that is no JSON object as no answer at all' do
    stub_request(:get, "#{Settings.oots_france_url}/requete/#{exchange_id}")
      .to_return(status: 501, body: 'Not Implemented Yet!')

    expect(client.fetch(exchange_id).exchange_status).to be_nil
  end

  # An address that does not answer is not a refusal, and Faraday's exception
  # stops here: the page that follows the exchange must never be the place where
  # this deployment names its HTTP library.
  it 'raises an outage of its own rather than letting the transport through' do
    stub_request(:get, "#{Settings.oots_france_url}/requete/#{exchange_id}").to_timeout

    expect { client.fetch(exchange_id) }
      .to raise_error(DemoContractError, /Le contrat n'a pas répondu/)
  end
end
