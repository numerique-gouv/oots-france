require 'rails_helper'

RSpec.describe EbmsIdentity do
  it { is_expected.to validate_presence_of(:id) }
  it { is_expected.to validate_presence_of(:type_id) }

  # An absent value reaches Domibus as a property it accepts without
  # complaint, and the message is then routed nowhere — a failure that shows up
  # only as silence on the other side.
  it 'rejects a blank scheme as firmly as a missing one' do
    expect(build(:ebms_identity, type_id: '   ')).not_to be_valid
  end

  describe '#validate!' do
    it 'names the party whose identity is unusable' do
      identity = build(:ebms_identity, id: nil)

      expect { identity.validate!(:requester) }
        .to raise_error(ConfigurationError, /\ALe requêteur : /)
    end

    it 'returns itself when valid, so it can be chained' do
      identity = build(:ebms_identity)

      expect(identity.validate!(:requester)).to be(identity)
    end
  end

  describe 'equality' do
    it 'compares on both members, not on object identity' do
      identity = build(:ebms_identity)
      same_values = build(:ebms_identity)

      expect(identity).to eq(same_values)
      expect(identity).not_to be(same_values)
    end

    it 'distinguishes two identifiers under different schemes' do
      expect(build(:ebms_identity)).not_to eq(build(:ebms_identity, type_id: 'autre'))
    end

    it 'hashes equal values alike, so they collapse in a Set' do
      expect([build(:ebms_identity), build(:ebms_identity)].uniq.size).to eq(1)
    end
  end
end
