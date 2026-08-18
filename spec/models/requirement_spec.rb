require 'rails_helper'

RSpec.describe Requirement do
  # The console addresses its own pages by this segment: the whole identifier
  # names `sr.acc.oots…` in acceptance and `sr.oots…` in production, so a path
  # built from it would break on the way to production.
  it 'takes its short name from the last segment of the Semantic Repository URL' do
    expect(build(:requirement).uuid).to eq('00000000-0000-0000-0000-000000000000')
  end

  it 'has no short name when the directory published no identifier' do
    expect(build(:requirement, id: nil).uuid).to be_nil
  end

  it 'answers the procedures and the countries declaring it' do
    requirement = build(:requirement, reference_frameworks: [
      build(:reference_framework, procedure_code: '00', country: 'FR'),
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
      build(:reference_framework, procedure_code: 'R1', country: 'BE'),
    ])

    expect(requirement.procedure_codes).to eq(%w[00 R1])
    expect(requirement.countries).to eq(%w[FR DE BE])
  end

  it 'leaves out a code or a country the directory published empty' do
    requirement = build(:requirement, reference_frameworks: [
      build(:reference_framework, procedure_code: '', country: ''),
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
    ])

    expect(requirement.procedure_codes).to eq(['R1'])
    expect(requirement.countries).to eq(['DE'])
  end

  # French where the directory publishes it, English otherwise — which every
  # entry of the catalogue carries. Inverting the two would name most of the
  # console in a language nobody asked for.
  it 'prefers the French name to the English one' do
    published = { 'EN' => 'Test Requirement', 'FR' => 'Exigence de test' }

    expect(build(:requirement, descriptions: published).label).to eq('Exigence de test')
    expect(build(:requirement, descriptions: published.except('FR')).label).to eq('Test Requirement')
    expect(build(:requirement, descriptions: { 'FI' => 'Testivaatimus' }).label).to eq('Testivaatimus')
  end

  # The directory nests declarations inside the requirement; a listing of
  # procedures walks the graph the other way.
  it 'names itself on each declaration it carries' do
    requirement = build(:requirement)

    expect(requirement.reference_frameworks.first.requirement).to be(requirement)
  end
end
