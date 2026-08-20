require 'rails_helper'

RSpec.describe Conversation do
  subject(:conversation) { create(:conversation) }

  it { is_expected.to validate_presence_of(:conversation_id) }
  it { is_expected.to validate_presence_of(:procedure_code) }
  it { is_expected.to validate_presence_of(:evidence_requester_id) }
  it { is_expected.to validate_uniqueness_of(:conversation_id) }
  it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }

  it 'starts in progress' do
    expect(conversation).not_to be_settled
  end

  # This is what the process-local emitter could not do: a notification handled
  # by one worker settles a conversation another worker opened.
  describe 'settling' do
    it 'records the evidence as delivered' do
      conversation.delivered!

      expect(conversation).to be_settled
      expect(conversation.settled_at).to be_present
    end

    # Not a failure: an instruction to send the user somewhere before asking
    # again. Chapter 4.9 resumes from here.
    it 'records where to send the user when a preview is required' do
      conversation.preview_required!('https://previsualisation.example.si/espace')

      expect(conversation).to have_attributes(
        status: 'preview_required',
        preview_location: 'https://previsualisation.example.si/espace',
      )
      expect(conversation).to be_settled
    end

    it 'records the EDM code when the correspondent refused' do
      conversation.failed!(code: 'EDM:ERR:0004', description: 'EDM:ERR:0004 : Object not found')

      expect(conversation).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0004')
    end
  end

  # Chapter 4.4, table 4.4.3: past the interval it configures, an exchange this
  # side opened and nobody answered is a failure, not a wait.
  describe 'expiring' do
    include ActiveSupport::Testing::TimeHelpers

    # `include` and not `contain_exactly`: the scope answers for the whole table,
    # and the end-to-end scenarios commit their own exchanges into the test
    # database — `Cucumber::Rails::World.use_transactional_tests` is false there.
    # An example may only speak for the rows it made.
    it 'takes an outgoing exchange nobody has settled' do
      overdue = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 1.minute)

      expect(described_class.expired).to include(overdue)
    end

    it 'takes one still waiting to be submitted, which nobody will answer either' do
      overdue = create(:conversation, created_at: Settings.requester_timeout.ago - 1.minute)

      expect(described_class.expired).to include(overdue)
    end

    it 'leaves an exchange already settled, however old' do
      settled = %i[delivered failed preview_required].map do |outcome|
        create(:conversation, outcome, created_at: Settings.requester_timeout.ago - 1.day)
      end

      expect(described_class.expired).not_to include(*settled)
    end

    # Where France answers, the timeout is an act of emission that
    # `EvidenceProvision::AnswerRequest` carries out: a row written here would
    # name an error nobody was ever sent.
    it 'leaves an exchange a correspondent addressed to France' do
      received = create(:conversation, incoming: true, country_code: 'BE', procedure_code: nil,
        evidence_requester_id: nil, created_at: Settings.requester_timeout.ago - 1.day)

      expect(described_class.expired).not_to include(received)
    end

    it 'leaves one sitting exactly on the cutoff' do
      freeze_time do
        borderline = create(:conversation, :sent, created_at: Settings.requester_timeout.ago)

        expect(described_class.expired).not_to include(borderline)
      end
    end

    # The same code a correspondent that times out on us would have answered:
    # who noticed the timeout must not change how the exchange reads.
    it 'reads as a failure under EDM:ERR:0005' do
      conversation.expire!

      expect(conversation).to have_attributes(
        status: 'failed',
        edm_error_code: 'EDM:ERR:0005',
        error_description: "Le correspondant n'a pas répondu dans le délai imparti.",
      )
      expect(conversation.settled_at).to be_present
    end

    it 'leaves alone an exchange a response settled first' do
      conversation.delivered!

      described_class.find(conversation.id).expire!

      expect(conversation.reload).to have_attributes(status: 'delivered', edm_error_code: nil)
    end

    # `EDM:ERR:0005` is a code a correspondent answers too, and France answers it
    # itself to a request that reached its deadline. Only what `expire!` wrote
    # is a presumption, and only the record says so.
    it 'reads no presumption into an answer carrying the very same code' do
      conversation.failed!(code: 'EDM:ERR:0005', description: 'Exceeding timeout period')

      described_class.find(conversation.id).failed!(code: 'EDM:ERR:0003', description: 'Rejouée')

      expect(conversation.reload.edm_error_code).to eq('EDM:ERR:0005')
    end

    it 'forgets the presumption once an answer has refuted it' do
      conversation.expire!

      described_class.find(conversation.id).delivered!

      expect(conversation.reload.presumed_at).to be_nil
    end

    # The other way round: an answer arrives on an exchange this side had given
    # up on, and settles it.
    it 'lets an answer overrule the guess' do
      conversation.expire!

      described_class.find(conversation.id).delivered!

      expect(conversation.reload).to have_attributes(status: 'delivered', edm_error_code: nil,
        error_description: nil)
    end

    # Every answer, not only the delivery — and a refusal is the likeliest of
    # them, a correspondent answering at last that it holds nothing. An exchange
    # that stops failing on our guess must name the failure it was told of, or
    # none at all.
    it 'clears what the guess wrote when a preview is asked for instead' do
      conversation.expire!

      described_class.find(conversation.id).preview_required!('https://previsualisation.example.si/espace')

      expect(conversation.reload).to have_attributes(status: 'preview_required', edm_error_code: nil,
        error_description: nil, presumed_at: nil)
    end

    it 'lets a refusal that arrives at last replace the guess' do
      conversation.expire!

      described_class.find(conversation.id).failed!(code: 'EDM:ERR:0004', description: 'Object not found')

      expect(conversation.reload).to have_attributes(edm_error_code: 'EDM:ERR:0004',
        error_description: 'Object not found', presumed_at: nil)
    end
  end

  describe 'the preview location' do
    # Last line of defence on a value a foreign correspondent chose, which is
    # rendered as a link target in a user's browser.
    it 'refuses a scheme that is not http or https' do
      conversation.preview_location = 'javascript:alert(document.domain)'

      expect(conversation).not_to be_valid
    end

    it 'accepts an https address' do
      conversation.preview_location = 'https://previsualisation.example.si/espace'

      expect(conversation).to be_valid
    end

    # `Conversation` is the one persisted record, so its translations live under
    # `activerecord` and not `activemodel`. Misfiled, the validation still fires
    # but the message falls back to Rails' generic one — which nothing would
    # notice without reading it out.
    it 'says so in French' do
      conversation.preview_location = 'javascript:alert(1)'
      conversation.valid?

      expect(conversation.errors.full_messages)
        .to eq(["L'adresse de prévisualisation doit être une adresse http ou https"])
    end
  end

  # The fallback sweep can pick up a message the push notification also
  # delivered. Both workers load their own instance, so a guard that reads the
  # status off memory and then writes lets both through.
  it 'refuses to settle an exchange another worker has already settled' do
    conversation.delivered!
    seen_by_another_worker = described_class.find(conversation.id)

    seen_by_another_worker.failed!(code: 'EDM:ERR:0004', description: 'trop tard')

    expect(conversation.reload).to have_attributes(status: 'delivered', edm_error_code: nil)
  end

  # A procedure belongs to the country that requests, and the solicited country
  # is the one the evidence is asked of: `incoming` says which of `country_code`
  # and France holds each role.
  describe 'the two countries an exchange stands between' do
    it 'has France asking a correspondent when France asks' do
      expect(build(:conversation, incoming: false, country_code: 'FI')).to have_attributes(
        requester_country_code: Settings.common_services_country_code,
        solicited_country_code: 'FI',
      )
    end

    it 'has a correspondent asking France when France answers' do
      expect(build(:conversation, incoming: true, country_code: 'BE')).to have_attributes(
        requester_country_code: 'BE',
        solicited_country_code: Settings.common_services_country_code,
      )
    end
  end

  # What an outgoing exchange always knows, a received one may not: a body too
  # malformed to read names nothing at all.
  it 'requires of an outgoing exchange what only it always knows' do
    expect(build(:conversation, incoming: false, country_code: nil)).not_to be_valid
    expect(build(:conversation, incoming: true, country_code: nil, procedure_code: nil,
      evidence_requester_id: nil)).to be_valid
  end

  # The direction does not turn round: both readings of `country_code` depend on
  # it, and a received exchange calling itself outgoing would name France as the
  # requester.
  it 'refuses to change direction once it is open' do
    conversation = create(:conversation, incoming: true, country_code: 'BE')

    expect { conversation.update!(incoming: false) }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(conversation.reload.requester_country_code).to eq('BE')
  end

  # Eight write sites for two columns, and no source agrees on case: both
  # filters upcase what they are asked.
  it 'upcases the country whoever wrote it' do
    expect(create(:conversation, country_code: 'fi').country_code).to eq('FI')
  end

  # Neither `dependent:` nor a database constraint: the two lifetimes are
  # independent, and a legal trace does not fall with the state it relates.
  it 'keeps its journal when it is destroyed' do
    conversation = create(:conversation)
    create(:audit_event, conversation_id: conversation.conversation_id)

    conversation.destroy!

    expect(AuditEvent.count).to eq(1)
  end

  # Chapter 4.4 correlates a response to its request by this identifier, and
  # the exchange is the only thing that remembers which one it sent.
  describe '#answers?' do
    subject(:conversation) { build(:conversation, request_id: 'urn:uuid:11111111-1111-4111-8111-111111111111') }

    it 'recognises the identifier it sent' do
      expect(conversation.answers?('urn:uuid:11111111-1111-4111-8111-111111111111')).to be(true)
    end

    it 'refuses an identifier that is not the one it sent' do
      expect(conversation.answers?('urn:uuid:22222222-2222-4222-8222-222222222222')).to be(false)
    end

    # Unknown is not different: exchanges opened before the column existed carry
    # nothing to compare against, and refusing them would break the ones in
    # flight at deployment.
    context 'when the exchange recorded no identifier' do
      subject(:conversation) { build(:conversation, request_id: nil) }

      it 'accepts what it cannot compare' do
        expect(conversation.answers?('urn:uuid:22222222-2222-4222-8222-222222222222')).to be(true)
      end
    end
  end
end
