require 'rails_helper'

RSpec.describe SubjectSearch do
  let(:person) { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' } }

  describe '#complete?' do
    it 'wants the three fields' do
      expect(described_class.new(**person)).to be_complete
    end

    it 'refuses two of them, which compose a key nobody has' do
      expect(described_class.new(family_name: 'Königreich', given_name: 'Ada')).not_to be_complete
    end
  end

  # Composed exactly as the writing composed it, or the deterministic column
  # answers nothing at all.
  it 'builds the key the way the journal stored it' do
    expect(described_class.new(**person).key).to eq(AuditEvent.subject_key(**person))
  end

  describe '#events' do
    it 'finds what concerns the person' do
      event = create(:audit_event, :about_a_person)

      expect(described_class.new(**person).events).to contain_exactly(event)
    end

    it 'finds nothing until the three fields are given' do
      create(:audit_event, :about_a_person)

      expect(described_class.new(family_name: 'Königreich', given_name: 'Ada').events).to be_empty
    end

    # `01/01/1990` composes a key nobody has: without the format, the page would
    # answer as though the person had never been asked about.
    it 'refuses a date of birth that is not ISO 8601' do
      search = described_class.new(**person, date_of_birth: '01/01/1990')

      expect(search.events).to be_empty
      expect(search).not_to be_searched
      expect(search.errors.full_messages).to contain_exactly(
        "#{I18n.t('activemodel.attributes.subject_search.date_of_birth')} " \
        "#{I18n.t('activemodel.errors.models.subject_search.attributes.date_of_birth.format')}",
      )
    end
  end
end
