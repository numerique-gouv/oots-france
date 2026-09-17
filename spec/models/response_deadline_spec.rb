require 'rails_helper'

# Chapter 4.4.3 writes two conditionals, one per role, on a single antecedent:
# a deployment may implement no timeout at all.
RSpec.describe ResponseDeadline do
  describe 'where the deployment implements no timeout' do
    before { allow(Settings).to receive(:timeout_enabled?).and_return(false) }

    it 'says so' do
      expect(described_class).not_to be_handled
    end

    # The conditional is read first, so that neither duration is asked for: no
    # duration is configured on a side that handles no timeout, and asking would
    # raise rather than answer.
    it 'names no instant, and reads no duration to name one' do
      allow(Settings).to receive(:requester_timeout).and_raise(ConfigurationError)
      allow(Settings).to receive(:provider_timeout).and_raise(ConfigurationError)

      expect([described_class.for_requester, described_class.for_provider]).to eq([nil, nil])
    end

    # An absent timeout, and not an infinite one: no request has arrived too
    # late where none can.
    it 'holds no request to have arrived too late' do
      expect(described_class).not_to be_passed(10.years.ago)
    end
  end

  describe 'where it does' do
    before do
      allow(Settings).to receive_messages(timeout_enabled?: true, requester_timeout: 30.minutes,
        provider_timeout: 10.minutes)
    end

    # The two durations are not one: the requester gives up on an answer that
    # never came, the data service refuses a request that arrived too late.
    it 'gives each side the duration configured for it' do
      expect(described_class.for_requester).to be_within(5.seconds).of(30.minutes.ago)
      expect(described_class.for_provider).to be_within(5.seconds).of(10.minutes.ago)
    end

    it 'holds a request older than the data service deadline to have arrived too late' do
      expect(described_class).to be_passed(11.minutes.ago)
    end

    it 'holds a request within it to be one France still owes an answer' do
      expect(described_class).not_to be_passed(9.minutes.ago)
    end
  end
end
