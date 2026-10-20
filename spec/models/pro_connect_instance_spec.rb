require 'rails_helper'

RSpec.describe ProConnectInstance do
  let(:declaration) { { issuer: 'https://auth.test/api/v2', client_id: 'un-client', client_secret: 'un-secret' } }

  it 'drops the trailing slash of the issuer, which every endpoint is compared against' do
    expect(described_class.new(**declaration, issuer: 'https://auth.test/api/v2/').issuer)
      .to eq('https://auth.test/api/v2')
  end

  %i[issuer client_id client_secret].each do |member|
    it "refuses a declaration whose #{member} holds nothing but blanks" do
      expect { described_class.new(**declaration, member => '  ') }.to raise_error(ArgumentError, /#{member}/)
    end
  end
end
