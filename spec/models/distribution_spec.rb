require 'rails_helper'

RSpec.describe Distribution do
  # The two families of the `OOTSMediaTypes` list, and a format it does not
  # carry, which belongs to neither.
  it 'tells the structured formats from the unstructured ones' do
    expect(described_class.new(format: 'application/json')).to have_attributes(structured?: true, unstructured?: false)
    expect(described_class.new(format: 'image/png')).to have_attributes(structured?: false, unstructured?: true)
    expect(described_class.new(format: 'image/jpg')).to have_attributes(structured?: false, unstructured?: false)
  end

  # The console names the rule it invokes, and the two are one sentence under
  # two identifiers: C039 judges an XML distribution, C041 a JSON one.
  it 'names the rule that requires its data model' do
    expect(described_class.new(format: 'application/xml').data_model_rule).to eq('R-DSD-RESP-C039')
    expect(described_class.new(format: 'application/json').data_model_rule).to eq('R-DSD-RESP-C041')
    expect(described_class.new(format: EvidenceType::PDF).data_model_rule).to be_nil
  end

  # The two lists are written apart, and the console reads them together: a
  # structured format the rules table forgot would send `nil` to the component
  # that names the rule, on the one branch that cannot guard against it.
  it 'names a rule for every format it counts as structured' do
    expect(described_class::DATA_MODEL_RULES.keys).to match_array(described_class::STRUCTURED_FORMATS)
  end
end
