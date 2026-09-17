require 'rails_helper'

RSpec.describe Demo::Journey do
  subject(:journey) { described_class.opened(previous:, subject: 'un-pseudonyme', uuid:) }

  let(:previous) { nil }
  # Frozen, so that what is minted can be told from what is carried over.
  let(:uuid) do
    values = %w[11111111-0000-4000-8000-000000000001 22222222-0000-4000-8000-000000000002]

    instance_double(UuidGenerator).tap { |generator| allow(generator).to receive(:next) { values.shift } }
  end

  describe '.opened' do
    it 'names both the journey and the conversation when nobody has walked before' do
      expect(journey).to have_attributes(
        id: '11111111-0000-4000-8000-000000000001',
        conversation_id: '22222222-0000-4000-8000-000000000002',
        subject: 'un-pseudonyme',
      )
    end

    # Chapter 4.4 §4.3.2: the conversation « SHOULD be reused for combined flows »
    # and is forbidden only « if the user authenticates with a different
    # identity ». Walking the demonstration again under the same pseudonym is
    # not one, so the conversation is carried over.
    context 'when the same user identifies anew' do
      let(:previous) do
        described_class.new(id: 'le-parcours-precedent', conversation_id: 'la-conversation', subject: 'un-pseudonyme')
      end

      it 'carries the conversation of the journey before' do
        expect(journey.conversation_id).to eq('la-conversation')
      end

      # What makes the previous journey's requests stop being followed: the
      # zone looks its own request up under the journey, and this is a new one.
      it 'takes an identifier of its own, the requests of the journey before not being its' do
        expect(journey.id).to eq('11111111-0000-4000-8000-000000000001')
      end
    end

    # « MUST NOT be reused if the user authenticates with a different identity »,
    # the pseudonym FranceConnect+ hands this service provider being what tells
    # one identity from another.
    context 'when another user identifies' do
      let(:previous) do
        described_class.new(id: 'le-parcours-precedent', conversation_id: 'la-conversation', subject: 'un-autre')
      end

      it 'mints a conversation of its own' do
        expect(journey.conversation_id).to eq('22222222-0000-4000-8000-000000000002')
      end
    end
  end

  # « A click writes nothing here » is what the whole fix rests on, and it is a
  # property of the type rather than of its callers: both factories hand back an
  # instance nothing can change afterwards.
  describe 'immutability' do
    it 'refuses to be changed once opened' do
      expect { journey.id = 'un-autre' }.to raise_error(FrozenError)
    end

    it 'refuses to be changed once read back from the session' do
      read = described_class.from_session(journey.to_session)

      expect { read.conversation_id = 'une-autre' }.to raise_error(FrozenError)
    end

    # Frozen and still answerable: the pages that rest on it validate it at
    # every request, and read all three of its attributes.
    it 'is still readable and still validates' do
      expect(described_class.from_session(journey.to_session)).to be_valid
    end
  end

  describe '.from_session' do
    # The cookie gives back string keys, which is the shape `to_session` is
    # written in and the one this reads.
    it 'reads back what it wrote' do
      expect(described_class.from_session(journey.to_session))
        .to have_attributes(journey.to_session.symbolize_keys)
    end

    it 'reads no journey from a session holding none' do
      expect(described_class.from_session(nil)).to be_nil
    end

    # A session written under a shape this class no longer reads is no session:
    # the pages resting on it send the user back to identify themself, which is
    # what they do with `nil`.
    it 'reads no journey from a payload naming something it no longer carries' do
      expect(described_class.from_session({ 'id' => 'un-parcours', 'echanges' => {} })).to be_nil
    end
  end

  # The one condition `HoldsDemoJourney` renders on: a journey missing any of
  # the three could neither name a conversation to ask under nor say whose
  # requests it is following.
  describe 'validity' do
    it 'is valid once opened' do
      expect(journey).to be_valid
    end

    %i[id conversation_id subject].each do |attribute|
      it "is invalid without #{attribute}" do
        expect(described_class.new(journey.to_session.except(attribute.to_s))).not_to be_valid
      end
    end
  end
end
