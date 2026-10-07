require 'rails_helper'

RSpec.describe Demo::ConfirmPreview do
  subject(:result) do
    described_class.call(request:, state:, identity:, resume_location:, confirmation_client: client, token_writer:)
  end

  let(:request) { registered_request }
  let(:identity) { Demo::UserIdentity.new(family_name: 'Sørensen') }
  let(:resume_location) { 'http://localhost:3000/admin/demo/v2.0/T1/documents' }
  let(:token_writer) { instance_double(Demo::BeneficiaryTokenWriter, call: 'un-jeton-chiffré') }
  let(:client) { instance_double(Demo::PreviewConfirmationClient, confirm: confirmation) }
  let(:descriptions) { [{ 'langue' => 'DE', 'texte' => 'Vorschau' }, { 'langue' => 'EN', 'texte' => 'Preview' }] }
  let(:state) do
    Demo::ContractAnswer.new(status: 200, payload: { 'statut' => 'preview_required',
                                                     'descriptionPrevisualisation' => descriptions })
  end
  let(:confirmation) do
    Demo::ContractAnswer.new(status: 202, payload: {
      'statut' => 'pending', 'adressePrevisualisation' => 'https://ap.example/preview?x=1',
      'methodePrevisualisation' => 'GET',
    })
  end

  it 'confirms with a token sealed from the identity and the return address it was given' do
    result

    expect(token_writer).to have_received(:call).with(identity)
    expect(client).to have_received(:confirm).with(exchange_id: request.exchange_id,
      encrypted_beneficiary: 'un-jeton-chiffré', resume_location:)
  end

  it 'keeps the link the confirmation answered' do
    result

    expect(request.reload).to have_attributes(preview_address: 'https://ap.example/preview?x=1',
      preview_method: 'GET', preview_body: nil)
  end

  # Chapter 4.9 §2 steps 10-11: « The Online Procedure Portal can filter the
  # natural language alternatives to match its presentation language ».
  it 'keeps the description in English, the language of the procedure' do
    result

    expect(request.reload).to have_attributes(preview_description: 'Preview', preview_description_language: 'EN')
  end

  context 'when the correspondent wrote no English' do
    let(:descriptions) { [{ 'langue' => 'DE', 'texte' => 'Vorschau' }, { 'langue' => 'FI', 'texte' => 'Esikatselu' }] }

    it 'keeps the first language it wrote' do
      result

      expect(request.reload).to have_attributes(preview_description: 'Vorschau', preview_description_language: 'DE')
    end
  end

  # A second confirmation receives `409`: the link kept says one was made.
  it 'confirms nothing a second time' do
    request.update!(preview_address: 'https://ap.example/preview')

    result

    expect(client).not_to have_received(:confirm)
  end

  context 'when the contract refuses the confirmation' do
    let(:confirmation) { Demo::ContractAnswer.new(status: 422, payload: { 'erreur' => 'adresse refusée' }) }

    it 'fails with what the contract said, and keeps nothing' do
      expect(result.error).to eq(key: :demo_preview_unconfirmed, errors: ['adresse refusée'])
      expect(request.reload.preview_address).to be_nil
    end
  end

  context 'when the beneficiary token cannot be sealed' do
    before { allow(token_writer).to receive(:call).and_raise(UnusableKeySetError, 'jeu de clés illisible') }

    it 'fails without asking the contract, and keeps nothing' do
      expect(result.error).to eq(key: :demo_preview_unconfirmed, errors: ['jeu de clés illisible'])
      expect(client).not_to have_received(:confirm)
      expect(request.reload.preview_address).to be_nil
    end
  end

  context 'when the contract does not answer' do
    before { allow(client).to receive(:confirm).and_raise(DemoContractError, 'injoignable') }

    it 'fails with the outage' do
      expect(result.error).to eq(key: :demo_preview_unconfirmed, errors: ['injoignable'])
    end
  end
end
