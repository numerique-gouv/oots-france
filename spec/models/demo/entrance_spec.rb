require 'rails_helper'

RSpec.describe Demo::Entrance do
  describe '.named' do
    it 'finds each entrance by its name' do
      expect(described_class.named('public')).to eq(described_class::PUBLIC)
      expect(described_class.named('console')).to eq(described_class::CONSOLE)
    end

    it 'falls back on the console for a name it does not know' do
      expect(described_class.named(nil)).to eq(described_class::CONSOLE)
      expect(described_class.named('ailleurs')).to eq(described_class::CONSOLE)
    end
  end

  it 'keeps the journey and the identity of each entrance apart' do
    console = described_class::CONSOLE
    public = described_class::PUBLIC

    expect([console.journey_key, *console.cookies]).not_to include(public.journey_key, *public.cookies)
  end

  it 'asks under the SIRET of each entrance' do
    expect(described_class::CONSOLE.requester_id).to eq(Settings.demo_requester_id)
    expect(described_class::PUBLIC.requester_id).to eq(Settings.public_demo_requester_id)
    expect(Settings.public_demo_requester_id).not_to eq(Settings.demo_requester_id)
  end

  describe 'the public entrance' do
    it 'opens where the real FranceConnect+ alone is declared' do
      declare_france_connect(real_france_connect)

      expect(described_class::PUBLIC).to be_open
    end

    it 'opens where the fake FranceConnect+ alone is declared' do
      declare_france_connect(fake_france_connect)

      expect(described_class::PUBLIC).to be_open
    end

    it 'stays closed where no FranceConnect+ is declared' do
      allow(Settings).to receive(:france_connect_instances).and_return([])

      expect(described_class::PUBLIC).not_to be_open
    end
  end
end
