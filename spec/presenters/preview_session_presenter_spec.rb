require 'rails_helper'

RSpec.describe PreviewSessionPresenter do
  # CA8: the size of the document follows the language of the page.
  it 'writes the size of the document in the language of the page' do
    presenter = described_class.new(build(:preview_session, document: Base64.strict_encode64('x' * 1_536)))

    expect(presenter.document_size).to eq('1,5 ko')
    expect(I18n.with_locale(:en) { presenter.document_size }).to eq('1.5 KB')
  end

  # Nothing of the request before the identity check, and a refusal instead
  # of it once failed.
  describe 'the identity check' do
    let(:session) { build(:preview_session) }

    it 'asks an unidentified browser to identify before the decision page' do
      expect(described_class.new(session)).to be_identification_required
      expect(described_class.new(session, verdict: :confirmed)).not_to be_identification_required
    end

    it 'asks nobody to identify to read that the link has run out' do
      session.issued_at = 17.minutes.ago

      expect(described_class.new(session)).not_to be_identification_required
    end

    it 'refuses a refused browser, and offers it no way back of an address it did not conclude' do
      presenter = described_class.new(session, verdict: :refused)

      expect(presenter.state).to eq(:refused)
      expect(presenter).not_to be_offers_return
    end

    it 'refuses any browser on an address the check concluded, offering the way back to the refused one alone' do
      session.assign_attributes(status: 'failed', identification: PreviewSession::MISMATCHED)

      expect(described_class.new(session)).to have_attributes(state: :refused, identification_required?: false,
        offers_return?: false)
      expect(described_class.new(session, verdict: :refused)).to have_attributes(offers_return?: true,
        follows_return?: false)
      expect(described_class.new(session, verdict: :confirmed)).to have_attributes(state: :refused,
        offers_return?: false)
      expect(described_class.new(session, verdict: :rejected)).to have_attributes(offers_return?: false)
    end

    # OOTS-287: no document matches the user, who reads so only once
    # recognised, and is never sent back on their own.
    it 'tells a recognised browser that no document matches, and asks any other to identify first' do
      session.assign_attributes(unmatched: true, document: nil, status: 'decided',
        return_location: 'https://portail.example/retour')

      expect(described_class.new(session)).to have_attributes(state: :unmatched, identification_required?: true)
      expect(described_class.new(session, verdict: :confirmed)).to have_attributes(state: :unmatched,
        identification_required?: false, offers_return?: true, leaves_by_redirection?: false)
    end

    it 'keeps an unmatched address open until the recognised browser reads it' do
      session.assign_attributes(unmatched: true, document: nil)

      expect(described_class.new(session)).to have_attributes(state: :open, identification_required?: true)
    end

    # The answer gone, nothing is left to check against: no second
    # identification, and the way back stays the deciding browser's.
    it 'asks nobody to identify once answered, and offers an unknown browser no way back' do
      session.assign_attributes(status: 'answered', return_location: 'https://portail.example/retour')
      presenter = described_class.new(session)

      expect(presenter).to have_attributes(state: :recorded, identification_required?: false, offers_return?: false,
        leaves_by_redirection?: false)
    end
  end
end
