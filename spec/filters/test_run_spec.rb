require 'rails_helper'

RSpec.describe TestRun do
  it 'starts from the case and the run the user names' do
    expect(described_class.new).to have_attributes(test_case: 'TC06', run: '01')
  end

  it 'accepts letters and digits, and two digits for the run' do
    expect(described_class.new(test_case: 'TC06', run: '02')).to be_valid
  end

  ['TC 06', '../TC06', "TC06\n", 'TÉ06', ''].each do |test_case|
    it "refuses #{test_case.inspect} as a test case, which would not make a file name" do
      test_run = described_class.new(test_case:)

      expect(test_run).not_to be_valid
      expect(test_run.errors[:test_case])
        .to eq([I18n.t('activemodel.errors.models.test_run.attributes.test_case.format')])
    end
  end

  %w[1 001 0a].each do |run|
    it "refuses #{run.inspect} as a run, which the convention writes with two digits" do
      test_run = described_class.new(run:)

      expect(test_run).not_to be_valid
      expect(test_run.errors[:run]).to eq([I18n.t('activemodel.errors.models.test_run.attributes.run.format')])
    end
  end
end
