require 'rails_helper'

RSpec.describe ExchangeFilter do
  def filter(params) = described_class.from(ActionController::Parameters.new(params))

  def results(params)
    built = filter(params)
    built.apply(Exchange.all, built.page_within(built.total(Exchange.all)))
  end

  describe '.from' do
    it 'ignores a parameter that is none of its business' do
      expect { filter(status: 'delivered', autre: 'valeur') }.not_to raise_error
    end
  end

  describe 'narrowing' do
    it 'keeps everything when nothing is asked' do
      create(:exchange, :delivered)
      create(:exchange, :failed)

      expect(results({}).count).to eq(2)
    end

    # Chapter 4.7: all the messages sharing a conversation « relate to that
    # person », which is what makes tracing and diagnosis possible. The console
    # gets there by narrowing the listing rather than by a page of its own.
    it 'gathers the exchanges of one conversation' do
      session = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'
      first = create(:exchange, conversation_id: session)
      second = create(:exchange, conversation_id: session)
      create(:exchange)

      expect(results(conversation_id: session)).to contain_exactly(first, second)
    end

    it 'combines criteria' do
      wanted = create(:exchange, :failed, country_code: 'FI')
      create(:exchange, :failed, country_code: 'DE')
      create(:exchange, :delivered, country_code: 'FI')

      expect(results(status: 'failed', country_code: 'FI')).to contain_exactly(wanted)
    end

    it 'narrows on the procedure alone' do
      wanted = create(:exchange, procedure_code: '00')
      create(:exchange, procedure_code: '01')

      expect(results(procedure_code: '00')).to contain_exactly(wanted)
    end

    it 'narrows on the requester alone' do
      wanted = create(:exchange, evidence_requester_id: '11111111111111')
      create(:exchange, evidence_requester_id: '22222222222222')

      expect(results(evidence_requester_id: '11111111111111')).to contain_exactly(wanted)
    end
  end

  describe 'the period' do
    it 'takes whole days at both ends' do
      inside = create(:exchange, created_at: Time.zone.parse('2026-08-10 23:30'))
      create(:exchange, created_at: Time.zone.parse('2026-08-11 00:30'))
      create(:exchange, created_at: Time.zone.parse('2026-08-09 23:30'))

      expect(results(depuis: '2026-08-10', jusqu_a: '2026-08-10')).to contain_exactly(inside)
    end

    it 'is open when only its start is given' do
      recent = create(:exchange, created_at: Time.zone.parse('2026-08-11 12:00'))
      create(:exchange, created_at: Time.zone.parse('2026-08-09 12:00'))

      expect(results(depuis: '2026-08-10')).to contain_exactly(recent)
    end

    it 'is open when only its end is given' do
      old = create(:exchange, created_at: Time.zone.parse('2026-08-09 12:00'))
      create(:exchange, created_at: Time.zone.parse('2026-08-11 12:00'))

      expect(results(jusqu_a: '2026-08-10')).to contain_exactly(old)
    end
  end

  # A criterion that is dropped rather than honoured shows every exchange under
  # a heading claiming otherwise, and nothing on screen tells the two apart.
  describe 'a criterion it cannot honour' do
    it 'refuses a status that is not one of the model’s' do
      create(:exchange, :delivered)

      expect(results(status: 'inexistant')).to be_empty
      expect(filter(status: 'inexistant')).not_to be_valid
    end

    it 'refuses a date it cannot read, rather than dropping it' do
      create(:exchange, :delivered)

      expect(results(depuis: 'pas-une-date')).to be_empty
    end

    it 'names the criterion it refused' do
      refused = filter(depuis: 'pas-une-date')
      refused.valid?

      expect(refused.errors).to be_of_kind(:depuis, :unreadable)
    end

    # `params.permit` drops a permitted key whose value has the wrong shape,
    # which would otherwise widen the list in silence.
    it 'refuses a criterion submitted with the wrong shape' do
      create(:exchange, :delivered)

      expect(results(status: %w[delivered failed])).to be_empty
    end

    it 'refuses an unreadable end date as it does a start date' do
      create(:exchange, :delivered)
      refused = filter(jusqu_a: 'pas-une-date')

      expect(results(jusqu_a: 'pas-une-date')).to be_empty
      expect(refused.tap(&:valid?).errors).to be_of_kind(:jusqu_a, :unreadable)
    end

    # Read the wrong way round a period matches nothing, which on screen is
    # indistinguishable from an exchange that never happened.
    it 'refuses a period whose end precedes its start' do
      refused = filter(depuis: '2026-08-20', jusqu_a: '2026-08-10')

      expect(refused).not_to be_valid
      expect(refused.errors).to be_of_kind(:jusqu_a, :before_start)
    end

    it 'accepts a period of a single day' do
      expect(filter(depuis: '2026-08-10', jusqu_a: '2026-08-10')).to be_valid
    end

    it 'reports no total it cannot stand behind' do
      create(:exchange, :delivered)

      expect(filter(depuis: 'pas-une-date').total(Exchange.all)).to eq(0)
    end

    # Built from values already typed rather than from a query string, there is
    # nothing submitted to find fault with — and nothing to silently drop.
    it 'finds no fault when nothing was submitted to it' do
      expect(described_class.new(depuis: Date.new(2026, 8, 10))).to be_valid
    end
  end

  describe 'paging' do
    it 'cuts into pages' do
      create_list(:exchange, described_class::PER_PAGE + 3, :delivered)

      expect(results({}).size).to eq(described_class::PER_PAGE)
      expect(results(page: 2).size).to eq(3)
    end

    it 'answers at least one page, even with no result' do
      expect(filter({}).pages(0)).to eq(1)
    end

    it 'rounds up to the next page' do
      expect(filter({}).pages(described_class::PER_PAGE + 1)).to eq(2)
    end

    it 'clamps a page below the first' do
      expect(filter(page: -3).page_within(4 * described_class::PER_PAGE)).to eq(1)
    end

    # Four pages, so the upper bound is distinguishable from the lower one: with
    # a single page both would answer 1, and a clamp to a constant would pass.
    it 'clamps a page past the last' do
      expect(filter(page: 999_999).page_within(4 * described_class::PER_PAGE)).to eq(4)
    end

    it 'leaves a page within the bounds alone' do
      expect(filter(page: 3).page_within(4 * described_class::PER_PAGE)).to eq(3)
    end

    # PostgreSQL refuses an offset wider than a 64-bit integer, and answered it
    # with a 500 before the clamp existed.
    it 'clamps a page no database could offset to' do
      create(:exchange, :delivered)

      expect { results(page: '99999999999999999999999999').to_a }.not_to raise_error
    end
  end

  describe '#to_query' do
    it 'carries the criteria over and replaces the page' do
      expect(filter(status: 'failed', page: 2).to_query(page: 3))
        .to include(status: 'failed', page: 3)
    end

    it 'drops the criteria left blank' do
      expect(filter(status: '', country_code: 'FI').to_query).not_to have_key(:status)
    end
  end
end
