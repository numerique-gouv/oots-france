require 'rails_helper'

RSpec.describe FranceConnectInstance do
  subject(:instance) { described_class.new(**declaration) }

  let(:declaration) do
    { name: 'real', issuer: 'https://auth.test/api/v2', client_id: 'un-client', client_secret: 'un-secret' }
  end

  it 'carries the declaration as it was given' do
    expect(instance).to have_attributes(name: 'real', issuer: 'https://auth.test/api/v2',
      client_id: 'un-client', client_secret: 'un-secret')
  end

  # `FranceConnectClient#under_issuer` refuses a published endpoint by comparing
  # the address it will call to this string as a prefix. A slash left on breaks
  # that comparison on the portal's own addresses — and that comparison is what
  # keeps the `client_secret` from travelling to whoever wrote the document.
  it 'drops the trailing slash of the issuer, which an endpoint is compared against' do
    expect(described_class.new(**declaration, issuer: 'https://auth.test/api/v2/').issuer)
      .to eq('https://auth.test/api/v2')
  end

  # Held by the type and not by the one caller that builds it today: an empty
  # issuer is an address of nothing, and an empty credential is refused at
  # `/token`, far from the deployment that could correct it.
  %i[issuer client_id client_secret].each do |member|
    it "refuses a declaration whose #{member} is absent" do
      expect { described_class.new(**declaration, member => nil) }
        .to raise_error(ArgumentError, /#{member}/)
    end

    it "refuses a declaration whose #{member} holds nothing but blanks" do
      expect { described_class.new(**declaration, member => '  ') }
        .to raise_error(ArgumentError, /#{member}/)
    end
  end
end
