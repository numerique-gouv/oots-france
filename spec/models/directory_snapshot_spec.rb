require 'rails_helper'

RSpec.describe DirectorySnapshot do
  let(:night) { Time.zone.local(2026, 11, 8, 2, 43) }

  describe '.record!' do
    it 'replaces the copy and its answers, and erases the failures before it' do
      first = described_class.record!({ 'a' => '<a/>' }, taken_at: night)
      described_class.record_failure!(code: nil, detail: 'Délai dépassé', failed_at: night + 1.day)

      second = described_class.record!({ 'b' => '<b/>' }, taken_at: night + 2.days)

      expect(described_class.current).to eq(second)
      expect(described_class.last_failure).to be_nil
      expect(DirectorySnapshot::Answer.pluck(:key)).to eq(['b'])
      expect(described_class.exists?(first.id)).to be(false)
    end

    it 'leaves the previous copy whole when writing the new one fails' do
      described_class.record!({ 'a' => '<a/>' }, taken_at: night)
      allow(DirectorySnapshot::Answer).to receive(:insert_all!).and_raise(ActiveRecord::StatementInvalid)

      expect { described_class.record!({ 'b' => '<b/>' }, taken_at: night + 1.day) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(described_class.current.taken_at).to eq(night)
      expect(described_class.current.answer('a')).to eq('<a/>')
    end
  end

  describe '.record_failure!' do
    it 'keeps the copy and its date, and the last failure alone, with its code' do
      described_class.record!({ 'a' => '<a/>' }, taken_at: night)
      described_class.record_failure!(code: nil, detail: 'Délai dépassé', failed_at: night + 1.day)
      described_class.record_failure!(code: 'DSD:ERR:0003', detail: 'refus', failed_at: night + 2.days)

      expect(described_class.current.taken_at).to eq(night)
      expect(described_class.failed.count).to eq(1)
      expect(described_class.last_failure).to have_attributes(failure_code: 'DSD:ERR:0003', failure_detail: 'refus')
    end
  end

  describe '#answer' do
    it 'raises for a question the copy holds no answer to' do
      snapshot = described_class.record!({}, taken_at: night)

      expect { snapshot.answer('absente') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
