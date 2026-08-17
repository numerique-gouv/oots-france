require 'rails_helper'

RSpec.describe Administrator do
  subject(:administrator) { create(:administrator) }

  it { is_expected.to validate_presence_of(:email) }

  it 'refuses a second account on the same address' do
    create(:administrator, email: 'operateur@example.com')

    expect { create(:administrator, email: 'operateur@example.com') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  # Normalisation and uniqueness only close the door together: each on its own
  # would let `Operateur@Example.com` open a second account.
  it 'refuses a second account whose address differs only in case' do
    create(:administrator, email: 'operateur@example.com')

    expect { create(:administrator, email: 'Operateur@Example.COM') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  # An operator typing their address at a login prompt does not reproduce the
  # case and the spacing they registered with.
  it 'holds the address stripped and in lower case' do
    expect(create(:administrator, email: '  Operateur@Example.COM ').email).to eq('operateur@example.com')
  end

  it 'refuses a password shorter than twelve characters' do
    expect { create(:administrator, password: 'court') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  # The length check must not fire on a record read back from the database,
  # whose `password` is nil.
  it 'saves an existing account without being given its password again' do
    stored = described_class.find(administrator.id)
    stored.update!(email: 'autre@example.com')

    expect(stored.reload.email).to eq('autre@example.com')
  end

  describe '.authenticate_by' do
    it 'returns the account when the password matches' do
      expect(described_class.authenticate_by(email: administrator.email, password: administrator.password))
        .to eq(administrator)
    end

    it 'returns nothing on a wrong password' do
      expect(described_class.authenticate_by(email: administrator.email, password: 'un-autre-mot-de-passe'))
        .to be_nil
    end

    it 'returns nothing on an address nobody registered' do
      expect(described_class.authenticate_by(email: 'personne@example.com', password: administrator.password))
        .to be_nil
    end

    it 'returns nothing on a blank password, rather than raising' do
      expect(described_class.authenticate_by(email: administrator.email, password: '')).to be_nil
    end

    # The address is normalised on the way into a query too, so the prompt need
    # not be case-exact.
    it 'matches the address whatever its case' do
      expect(described_class.authenticate_by(email: administrator.email.upcase, password: administrator.password))
        .to eq(administrator)
    end
  end
end
