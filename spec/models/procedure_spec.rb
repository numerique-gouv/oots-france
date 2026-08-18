require 'rails_helper'

RSpec.describe Procedure do
  subject(:procedure) { described_class.new(code: 'R1', declarations:) }

  let(:declarations) do
    german = build(:requirement, id: 'https://sr/un', reference_frameworks: [
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
    ])
    belgian = build(:requirement, id: 'https://sr/deux', reference_frameworks: [
      build(:reference_framework, procedure_code: 'R1', country: 'BE'),
      build(:reference_framework, procedure_code: 'R1', country: 'AT'),
    ])

    [german, belgian].flat_map(&:reference_frameworks)
  end

  it 'answers the countries having declared it, in order' do
    expect(procedure.countries).to eq(%w[AT BE DE])
  end

  # The page announcing how many countries declared a procedure lists them just
  # below: a declaration the directory published without its jurisdiction must
  # leave both, or the listing shows one entry more than the count.
  it 'leaves a declaration without a jurisdiction out of the listing as out of the count' do
    stateless = build(:reference_framework, procedure_code: 'R1', country: '')
    grouped = described_class.new(code: 'R1', declarations: declarations + [stateless])

    expect(grouped.declarations_by_country.keys).to eq(grouped.countries)
    expect(grouped.declarations_by_country.keys).to eq(%w[AT BE DE])
  end

  # A procedure named « » reaches the path helper, which refuses it — and the
  # guard holds whatever the caller built its declarations from, where the
  # parser already renders a missing code as nil.
  it 'leaves out a declaration whose code the directory published empty' do
    declared = build(:reference_framework, procedure_code: '', country: 'IT')

    expect(described_class.group(declarations + [declared]).map(&:code)).to eq(['R1'])
  end

  # Two member states declaring the same procedure under the same requirement
  # is the ordinary case, and the requirement must be named once.
  it 'answers the requirements its declarations rest on, without repeating one' do
    expect(procedure.requirements.map(&:id)).to eq(%w[https://sr/un https://sr/deux])
  end

  # A country files several declarations resting on one requirement, and it is
  # requirements that the pages leading here count.
  it 'groups by requirement what one country declared, and leaves the others out' do
    twice = build(:requirement, id: 'https://sr/un', reference_frameworks: [
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
    ]).reference_frameworks

    grouped = described_class.new(code: 'R1', declarations: declarations + twice)
      .declared_requirements('DE')

    expect(grouped.keys).to eq(['https://sr/un'])
    expect(grouped['https://sr/un'].size).to eq(2)
  end
end
