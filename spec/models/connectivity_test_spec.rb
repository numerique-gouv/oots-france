require 'rails_helper'

RSpec.describe ConnectivityTest do
  let(:party) do
    PmodeParty.new(name: 'AP_EL_01', identifier: 'AP_EL_01',
      identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL', endpoint: nil)
  end

  describe '.request' do
    it 'records a pending test towards the party' do
      test = described_class.request(party)

      expect(test).to have_attributes(party_name: 'AP_EL_01', party_identifier: 'AP_EL_01', outcome: 'pending')
    end

    it 'replaces the last test, and forgets what it said' do
      create(:connectivity_test, :submitted, party_name: 'AP_EL_01', outcome: 'refused_for_configuration',
        error_code: 'EBMS:0003', error_detail: 'No matching party found', verdict_read_at: Time.current)

      test = described_class.request(party)

      expect(described_class.count).to eq(1)
      expect(test).to have_attributes(outcome: 'pending', message_id: nil, error_code: nil,
        error_detail: nil, verdict_read_at: nil)
    end

    # Two first requests at the same instant: neither finds a row to lock, and
    # the second meets the first's on the unique index.
    it 'restarts nothing when a first request for the same party got there first' do
      create(:connectivity_test, party_name: 'AP_EL_01')
      unseen = true
      allow(described_class).to receive(:lock).and_wrap_original do |original|
        next original.call unless unseen

        unseen = false
        described_class.none
      end

      expect(described_class.request(party)).to be_nil
      expect(described_class.count).to eq(1)
    end

    it 'restarts nothing pending' do
      pending_test = create(:connectivity_test, party_name: 'AP_EL_01')

      expect(described_class.request(party)).to be_nil
      expect(pending_test.reload.requested_at).to eq(pending_test.requested_at)
    end
  end

  describe '#failed!' do
    let(:test) { create(:connectivity_test, :submitted) }

    it 'reads a refusal for the configuration of the access point' do
      test.failed!(DeliveryError.new(code: 'EBMS_0003', detail: 'No matching party found'))

      expect(test).to have_attributes(outcome: 'refused_for_configuration', error_code: 'EBMS:0003',
        error_detail: 'No matching party found')
    end

    it 'reads any other code as a failure' do
      test.failed!(DeliveryError.new(code: 'EBMS_0005', detail: 'Connection refused'))

      expect(test).to have_attributes(outcome: 'failed', error_code: 'EBMS:0005')
    end

    it 'reads a failure without a code' do
      test.failed!(nil)

      expect(test).to have_attributes(outcome: 'failed', error_code: nil)
    end
  end

  describe '.overdue' do
    it 'holds the pending tests asked more than fifteen minutes ago, submitted or not' do
      late = create(:connectivity_test, requested_at: 16.minutes.ago)
      late_submitted = create(:connectivity_test, :submitted, requested_at: 16.minutes.ago)
      create(:connectivity_test, requested_at: 14.minutes.ago)
      create(:connectivity_test, :acknowledged, requested_at: 1.day.ago)

      expect(described_class.overdue).to contain_exactly(late, late_submitted)
    end
  end
end
