require 'rails_helper'

RSpec.describe Address do
  # R-EDM-REQ-C073 and its response and error counterparts require an address
  # on agents classified ER, EP and ERRP, and require the country within it.
  it 'defaults to France, the only country this deployment speaks for' do
    expect(described_class.new.country).to eq('FR')
  end

  it 'is valid with a two-letter country code' do
    expect(build(:address, country: 'DE')).to be_valid
  end

  it 'rejects a country name written out, which the TDD do not admit' do
    expect(build(:address, country: 'France')).not_to be_valid
  end

  it 'rejects a lowercase code' do
    expect(build(:address, country: 'fr')).not_to be_valid
  end

  # The message and the attribute name both come from `config/locales/fr.yml`.
  # A missing key renders as "translation missing", which no test would catch
  # unless one reads the message out.
  it 'says so in French, attribute name included' do
    address = build(:address, country: 'France')
    address.valid?

    expect(address.errors.full_messages).to eq(['Le pays doit être un code pays à deux lettres'])
  end
end
