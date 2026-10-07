require 'rails_helper'

RSpec.describe Demo::PreviewConfirmationClient do
  subject(:answer) do
    described_class.new.confirm(exchange_id:, encrypted_beneficiary: 'un-jeton-chiffré',
      resume_location: 'http://localhost:3000/admin/demo/v2.0/T1/documents')
  end

  let(:exchange_id) { 'aaaaaaaa-0000-4000-8000-000000000001' }
  let(:address) { "#{Settings.oots_france_url}/requete/#{exchange_id}/previsualisation" }

  # The second call `docs/oots_context.md` gives a French service provider, with
  # the token again and the address the user is brought back to.
  it 'posts the beneficiary token and the return address to the confirmation' do
    stub_request(:post, address).to_return(status: 202, body: {
      adressePrevisualisation: 'https://ap.example/preview', methodePrevisualisation: 'GET',
    }.to_json)

    answer

    expect(WebMock).to have_requested(:post, address).with(body: {
      'beneficiaire' => 'un-jeton-chiffré', 'adresseRetour' => 'http://localhost:3000/admin/demo/v2.0/T1/documents',
    })
  end

  it 'reads the link the confirmation answers' do
    stub_request(:post, address).to_return(status: 202, body: {
      adressePrevisualisation: 'https://ap.example/preview', methodePrevisualisation: 'POST',
      corpsPrevisualisation: 'returnurl=x&returnmethod=GET',
    }.to_json)

    expect(answer).to be_confirmed
    expect(answer).to have_attributes(preview_location: 'https://ap.example/preview', preview_method: 'POST',
      preview_body: 'returnurl=x&returnmethod=GET')
  end

  # A confirmation the exchange no longer awaited is an answer, not an outage.
  it 'returns a refusal rather than raising on it' do
    stub_request(:post, address).to_return(status: 409, body: { erreur: 'déjà confirmée' }.to_json)

    expect(answer).not_to be_confirmed
    expect(answer.error).to eq('déjà confirmée')
  end

  it 'raises an outage of its own rather than letting the transport through' do
    stub_request(:post, address).to_timeout

    expect { answer }.to raise_error(DemoContractError, /confirmation de la prévisualisation/)
  end
end
