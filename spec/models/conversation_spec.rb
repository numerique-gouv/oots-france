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

  # Une démarche appartient au pays qui requête, et le pays sollicité est celui à
  # qui le justificatif est demandé : `incoming` dit lequel de `country_code` et
  # de la France tient chaque rôle.
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

  # Ce qu'un échange sortant sait toujours, un reçu peut l'ignorer : un corps
  # trop malformé pour être lu ne nomme rien.
  it 'requires of an outgoing exchange what only it always knows' do
    expect(build(:conversation, incoming: false, country_code: nil)).not_to be_valid
    expect(build(:conversation, incoming: true, country_code: nil, procedure_code: nil,
      evidence_requester_id: nil)).to be_valid
  end

  # Le sens ne se retourne pas : les deux lectures de `country_code` en dépendent,
  # et un échange reçu qui se dirait émis nommerait la France comme requêteur.
  it 'refuses to change direction once it is open' do
    conversation = create(:conversation, incoming: true, country_code: 'BE')

    expect { conversation.update!(incoming: false) }
      .to raise_error(ActiveRecord::ReadonlyAttributeError)
    expect(conversation.reload.requester_country_code).to eq('BE')
  end

  # Huit points d'écriture pour deux colonnes, et aucune source d'accord sur la
  # casse : les deux filtres majusculent ce qu'on leur demande.
  it 'upcases the country whoever wrote it' do
    expect(create(:conversation, country_code: 'fi').country_code).to eq('FI')
  end

  # Ni `dependent:` ni contrainte en base : les deux durées de vie sont
  # indépendantes, et une trace légale ne tombe pas avec l'état qu'elle relate.
  it 'keeps its journal when it is destroyed' do
    conversation = create(:conversation)
    create(:audit_event, conversation_id: conversation.conversation_id)

    conversation.destroy!

    expect(AuditEvent.count).to eq(1)
  end
end
