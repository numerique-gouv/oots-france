require 'rails_helper'

# OOTS-308: the demonstration procedure, identified by the fake FranceConnect+,
# dispensed from identifying again on a deployment that re-authenticates by the
# real one — and nobody else.
RSpec.describe PreviewDispensation do
  let(:preview_session) { create(:preview_session) }
  let(:journey) do
    Demo::Journey.new(id: 'parcours-1', conversation_id: 'conversation-1', subject: 'sub',
      specification: EdmSpecification::V2_0, procedure_code: ProcedureCode::ADMITTED.first)
  end
  let(:real) { FranceConnectInstance.new(name: 'real', issuer: 'https://vrai.example', client_id: 'a', client_secret: 'b') }
  let(:beneficiary) { RetrievedMessageParser.new(preview_session.first_request).body.beneficiary }

  def identity(**overrides)
    Demo::UserIdentity.new(given_name: 'Sophie', family_name: 'Dupont', birthdate: '1965-11-25',
      level_of_assurance: 'Substantial', subject: 'sub', id_token: 'jeton', france_connect: 'fake', **overrides)
  end

  def dispensation(**overrides)
    described_class.new(identity: identity, journey:, preview_session:, beneficiary:, instance: real, **overrides)
  end

  before do
    registered_request(SecureRandom.uuid, journey_id: journey.id, preview_address: preview_session.location)
  end

  it 'is granted to the subject of a request of this journey, identified by the fake' do
    expect(dispensation).to be_granted
  end

  it 'is refused to a browser holding no identity' do
    expect(dispensation(identity: nil)).not_to be_granted
  end

  it 'is refused to an identity of the real FranceConnect+' do
    expect(dispensation(identity: identity(france_connect: 'real'))).not_to be_granted
  end

  # Where the space would send the browser to the fake, it re-authenticates there.
  it 'is refused where the space identifies by the fake FranceConnect+' do
    fake = FranceConnectInstance.new(name: 'fake', issuer: 'https://faux.example', client_id: 'a', client_secret: 'b')

    expect(dispensation(instance: fake)).not_to be_granted
    expect(dispensation(instance: nil)).not_to be_granted
  end

  it 'is refused to a browser holding no journey' do
    expect(dispensation(journey: nil)).not_to be_granted
  end

  it 'is refused for a request another journey made' do
    other = Demo::Journey.new(journey.attributes.merge('id' => 'parcours-2'))

    expect(dispensation(journey: other)).not_to be_granted
  end

  it 'is refused where the request of this journey leads to another address' do
    Demo::Request.update_all(preview_address: create(:preview_session).location)

    expect(dispensation).not_to be_granted
  end

  it 'is refused to an identity that is not the subject of the request' do
    expect(dispensation(identity: identity(birthdate: '1965-11-26'))).not_to be_granted
  end
end
