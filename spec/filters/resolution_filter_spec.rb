require 'rails_helper'

RSpec.describe ResolutionFilter do
  # The page opens on a form, and nothing goes out until both halves of the
  # question are named.
  it 'is not a question until a procedure and a country are both named' do
    expect(filter(procedure_code: '00', country_code: 'FI')).to be_asked
    expect(filter(procedure_code: '00')).not_to be_asked
    expect(filter(country_code: 'FI')).not_to be_asked
    expect(filter({})).not_to be_asked
  end

  it 'upcases the country, whatever case it was written in' do
    expect(filter(country_code: 'fi').country).to eq('FI')
  end

  it 'refuses a country written out rather than asking the directory with it' do
    asked = filter(procedure_code: '00', country_code: 'Finlande')

    expect(asked).not_to be_asked
    expect(asked.errors[:country_code]).to be_present
  end

  # `params.permit` drops a permitted key whose value has the wrong shape, and
  # leaves no trace of having done so.
  it 'reports a criterion of the wrong shape' do
    asked = filter(procedure_code: '00', country_code: 'FI', requirement_id: %w[aaa bbb])

    expect(asked).not_to be_asked
    expect(asked.errors[:requirement_id]).to be_present
  end

  describe 'carrying the question to another link' do
    it 'keeps what was asked' do
      expect(filter(procedure_code: '00', country_code: 'FI').to_query(requirement_id: 'aaa'))
        .to eq(procedure_code: '00', country_code: 'FI', requirement_id: 'aaa')
    end

    # Choosing another requirement must drop the evidence type chosen under the
    # previous one, which is what passing it as nil does — and would not, were
    # the blanks dropped before the overrides rather than after.
    it 'lets an override drop a criterion by passing it as nil' do
      asked = filter(procedure_code: '00', country_code: 'FI', requirement_id: 'aaa', evidence_type_id: 'xxx')

      expect(asked.to_query(requirement_id: 'bbb', evidence_type_id: nil))
        .to eq(procedure_code: '00', country_code: 'FI', requirement_id: 'bbb')
    end
  end

  def filter(params) = described_class.from(ActionController::Parameters.new(params))
end
