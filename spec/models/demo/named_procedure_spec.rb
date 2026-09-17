require 'rails_helper'

RSpec.describe Demo::NamedProcedure do
  # Requirement 27 of chapter 1 §2 makes the evidence type and the provider a
  # condition of the request and says nothing of the procedure's own title,
  # which no directory owes anyone: a procedure nobody has named is still one a
  # user may ask under.
  it 'is valid naming nothing at all' do
    expect(described_class.new).to be_valid
  end

  describe '.from_session' do
    it 'reads back the string keys the cookie gives' do
      expect(described_class.from_session('procedure_name' => 'Study financing', 'procedure_language' => 'EN'))
        .to have_attributes(procedure_name: 'Study financing', procedure_language: 'EN')
    end

    it 'names nothing of a session written under an earlier shape' do
      expect(described_class.from_session('title' => 'Study financing')).to have_attributes(procedure_name: nil)
    end

    it 'names nothing when the session holds nothing' do
      expect(described_class.from_session(nil)).to have_attributes(procedure_name: nil)
    end
  end

  describe '#to_session' do
    it 'leaves out what no directory named' do
      expect(described_class.new(procedure_name: 'Study financing').to_session)
        .to eq('procedure_name' => 'Study financing')
    end
  end
end
