require 'rails_helper'

RSpec.describe BusinessRuleViolation do
  # The rule and what it says, in one sentence: the journal keeps a single
  # column, and an identifier alone would send whoever reads it to the TDD to
  # find out what was broken.
  it 'composes the rule and what it says' do
    violation = described_class.new(rule: 'R-EDM-RESP-C002', description: 'La réponse reçue annonce oots-edm:v1.0.')

    expect(violation.sentence).to eq('R-EDM-RESP-C002 : La réponse reçue annonce oots-edm:v1.0.')
  end
end
