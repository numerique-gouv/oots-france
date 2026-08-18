require 'rails_helper'

RSpec.describe Directories::Catalogue do
  subject(:catalogue) { described_class.new(evidence_broker:) }

  let(:evidence_broker) { instance_double(EvidenceBrokerClient, requirements: published) }

  let(:published) do
    [
      build(:requirement, id: 'https://sr/exigences/aaa', reference_frameworks: [
        build(:reference_framework, procedure_code: 'X10', country: 'DE'),
        build(:reference_framework, procedure_code: 'R1', country: 'BE'),
      ]),
      build(:requirement, id: 'https://sr/exigences/bbb', reference_frameworks: [
        build(:reference_framework, procedure_code: 'X2', country: 'FR'),
        build(:reference_framework, procedure_code: 'R1', country: 'FR'),
      ]),
    ]
  end

  # A declaration the directory published without its jurisdiction names no
  # country, and counting it would announce one member state more than there
  # are — on the very page an operator opens to see how many there are.
  it 'leaves out a declaration whose jurisdiction the directory published empty' do
    published << build(:requirement, id: 'https://sr/exigences/ccc', reference_frameworks: [
      build(:reference_framework, procedure_code: 'R1', country: ''),
    ])

    expect(catalogue.countries).to eq(%w[BE DE FR])
  end

  # The directory publishes no procedure as such: it holds the declarations
  # member states make, each naming the code it maps onto.
  it 'builds a procedure out of the declarations naming the same code' do
    expect(catalogue.procedure('R1').countries).to eq(%w[BE FR])
    expect(catalogue.procedure('R1').requirements.map(&:id)).to eq(%w[https://sr/exigences/aaa https://sr/exigences/bbb])
  end

  # Sorted on the letters and the number apart: plain string order would file
  # `X10` between `X1` and `X2`.
  it 'orders the procedures as a reader expects to find them' do
    expect(catalogue.procedures.map(&:code)).to eq(%w[R1 X2 X10])
  end

  it 'answers nothing for a code no member state has declared' do
    expect(catalogue.procedure('T3')).to be_nil
  end

  it 'finds a requirement by the short name the console addresses it with' do
    expect(catalogue.requirement('bbb').id).to eq('https://sr/exigences/bbb')
  end

  it 'lists the countries appearing anywhere in the catalogue' do
    expect(catalogue.countries).to eq(%w[BE DE FR])
  end

  # A declaration with no code belongs to no procedure, and a heading with no
  # name is worse than a line missing from a listing.
  it 'leaves out a declaration published without a procedure code' do
    published << build(:requirement, id: 'https://sr/exigences/ccc', reference_frameworks: [
      build(:reference_framework, procedure_code: nil, country: 'IT'),
    ])

    expect(catalogue.procedures.map(&:code)).to eq(%w[R1 X2 X10])
  end

  # `CommonServicesQuery` caches the body rather than what was read from it, so
  # a second ask costs a second parse of some six hundred kilobytes.
  it 'asks the directory once, however many angles the page reads it from' do
    catalogue.procedures
    catalogue.requirements
    catalogue.countries

    expect(evidence_broker).to have_received(:requirements).once
  end
end
