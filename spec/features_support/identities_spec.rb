require File.expand_path('../../features/support/fake_france_connect/identities', __dir__)

# The fake FranceConnect+ lives under `features/support/`, and the end-to-end
# scenario shows what it answers as a whole. What is checked here is the one
# rule the sources dictate claim by claim, and that a green scenario would only
# show indirectly: which claims a scope covers, and which a European user has
# not got at all.
RSpec.describe FakeFranceConnect::Identity do
  let(:substantial) { FakeFranceConnect::Identities.find('dk-substantial') }
  let(:high) { FakeFranceConnect::Identities.find('dk-high') }

  it 'traduit le niveau eIDAS de l\'identité en valeur ACR' do
    expect(substantial.acr).to eq('eidas2')
    expect(high.acr).to eq('eidas3')
  end

  describe '#claims_for' do
    it 'ne rend que ce que les scopes demandés couvrent' do
      expect(substantial.claims_for(%w[openid given_name family_name])).to eq(
        'given_name' => 'Freja Marie', 'family_name' => 'Sørensen',
      )
    end

    it 'omet les claims que l\'identité n\'a pas' do
      expect(high.claims_for(%w[openid gender birthplace])).to be_empty
    end

    # The scope `family_name` yields a family name and nothing else: the core
    # publishes `preferred_username` under `profile` and under a scope of its
    # own.
    it 'ne rend preferred_username que sous profile ou sous son propre scope' do
      expect(substantial.claims_for(%w[family_name])).not_to include('preferred_username')
      expect(substantial.claims_for(%w[preferred_username])).to eq('preferred_username' => 'Sørensen')
      expect(substantial.claims_for(%w[profile])).to include('preferred_username' => 'Sørensen')
    end

    # What the bridge does **not** render of a European user: no eIDAS
    # identifier, no country, no `birthcountry`, no `email`. The fake
    # reproduces the gap rather than filling it.
    it 'ne rend ni identifiant, ni pays, ni birthcountry, ni email' do
      everything = FakeFranceConnect::Identity::CLAIMS_BY_SCOPE.keys

      expect(substantial.claims_for(everything).keys).to contain_exactly(
        'given_name', 'family_name', 'birthdate', 'gender', 'birthplace', 'preferred_username',
      )
    end
  end

  describe FakeFranceConnect::Identities do
    it 'sert au moins une identité danoise de chaque niveau' do
      expect(described_class.of_country('DK').map(&:acr)).to include('eidas2', 'eidas3')
    end

    it 'n\'offre que les pays dont il a une identité' do
      expect(described_class.countries).to eq(%w[DK])
    end
  end
end
