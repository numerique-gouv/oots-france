require 'rails_helper'

RSpec.describe SubjectSearch do
  let(:person) { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' } }

  let(:organisation) { { legal_person_identifier: 'FR/DE/A2635542Y' } }

  describe '#complete?' do
    it 'wants the three fields' do
      expect(described_class.new(**person)).to be_complete
    end

    it 'refuses two of them, which compose a key nobody has' do
      expect(described_class.new(family_name: 'Königreich', given_name: 'Ada')).not_to be_complete
    end

    # The organisation's key is one field: chapter 4.5.1 gives the slot a
    # cardinality of 1..1 and describes its value as the identifier eIDAS
    # assorts to the organisation. `R-EDM-REQ-C049` only demands it be
    # provided, and no rule asserts the uniqueness.
    it 'wants the identifier alone of an organisation' do
      expect(described_class.new(**organisation)).to be_complete
    end

    it 'refuses the two identities together, which are two questions' do
      expect(described_class.new(**person, **organisation)).not_to be_complete
    end
  end

  # `complete?` sees a whole identity here — one field of a person is not one —
  # so what refuses is `reject_both_identities`, on `any?` and not on a whole
  # person. Asked of `searched?`, which is where the two meet: honouring the
  # identifier and dropping the name would answer about the organisation a
  # question that named someone else too.
  describe '#searched?' do
    it 'refuses a single field of a person left beside an identifier' do
      expect(described_class.new(family_name: 'Königreich', **organisation)).not_to be_searched
    end
  end

  # Composed exactly as the writing composed it, or the deterministic column
  # answers nothing at all.
  it 'builds the key the way the journal stored it' do
    expect(described_class.new(**person).key).to eq(AuditEvent.subject_key(**person))
  end

  it 'builds the organisation key the way the journal stored it' do
    expect(described_class.new(**organisation).key)
      .to eq(AuditEvent.legal_subject_key(eidas_identifier: 'FR/DE/A2635542Y'))
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

    it 'finds what concerns the organisation' do
      event = create(:audit_event, :about_an_organisation)

      expect(described_class.new(**organisation).events).to contain_exactly(event)
    end

    # The escape is only worth anything if both ends apply it: a deterministic
    # column answers a value composed exactly as it was stored, so a name
    # written escaped and searched raw would find nothing — and the page would
    # say « aucun événement ne concerne cette personne » of a person the journal
    # holds. Asked through the column and not on the composed string, which is
    # the only way to see the two ends agree.
    it 'finds a person whose name carried the separator the key is joined on' do
      named_with_one = { family_name: 'Legal|Sophie', given_name: 'Ada', date_of_birth: '1990-01-01' }
      event = create(:audit_event, :about_a_person, person: named_with_one)

      expect(described_class.new(**named_with_one).events).to contain_exactly(event)
    end

    # `FR/FR/AB|123456` is what R-EDM-REQ-C051 admits: `XX/YY/` then a segment
    # asked only to be non-blank.
    it 'finds an organisation whose conformant identifier carried the separator' do
      event = create(:audit_event, :about_an_organisation,
        organisation: build(:legal_person, eidas_identifier: 'FR/FR/AB|123456'))

      expect(described_class.new(legal_person_identifier: 'FR/FR/AB|123456').events).to contain_exactly(event)
    end

    # The identifier has one writing, the one that arrived, and the key folds
    # its case — so no format rule is owed here, unlike the date of birth.
    it 'ignores the case an identifier was typed in' do
      event = create(:audit_event, :about_an_organisation)

      expect(described_class.new(legal_person_identifier: 'fr/de/a2635542y').events)
        .to contain_exactly(event)
    end

    # Equality and nothing else, on this identity as on the other.
    it 'matches nothing on an identifier that is merely close' do
      create(:audit_event, :about_an_organisation)

      expect(described_class.new(legal_person_identifier: 'FR/DE/A2635542').events).to be_empty
    end

    # Honouring one and dropping the other would answer a question nobody put.
    it 'refuses the two identities submitted together' do
      search = described_class.new(**person, **organisation)

      expect(search.events).to be_empty
      expect(search).not_to be_searched
      expect(search.errors.full_messages).to contain_exactly(
        I18n.t('activemodel.errors.models.subject_search.both_identities'),
      )
    end

    # Each composes a key nobody has: without the validation, the page would
    # answer as though the person had never been asked about.
    [
      ['is not ISO 8601', '01/01/1990'],
      ['the calendar has not', '1990-13-32'],
    ].each do |what, typed|
      it "refuses a date of birth that #{what}" do
        search = described_class.new(**person, date_of_birth: typed)

        expect(search.events).to be_empty
        expect(search).not_to be_searched
        expect(search.errors.full_messages).to contain_exactly(
          "#{I18n.t('activemodel.attributes.subject_search.date_of_birth')} " \
          "#{I18n.t('activemodel.errors.models.subject_search.attributes.date_of_birth.format')}",
        )
      end
    end
  end
end
