require 'rails_helper'

RSpec.describe RequirementsResponseParser do
  subject(:identifiers) { described_class.new(body).requirement_identifiers }

  let(:body) { common_services_answer('eb_requirements_fr').first }

  # France maps its test procedure onto the requirement the Commission
  # publishes for smoke tests, which every member state may point its own
  # evidence types at.
  it 'reads the requirement the procedure imposes' do
    expect(identifiers)
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000'])
  end

  # Without it the second query would go out with an empty `requirement-id`,
  # and what came back would depend on how tolerant the directory happens to be.
  it 'refuses a requirement the directory published without an identifier' do
    stripped = body.sub(%r{<sdg:Identifier>.*?</sdg:Identifier>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /sans identifiant/)
  end

  # A directory with nothing to give says so by refusing — `EB:ERR:0001`,
  # `DSD:ERR:0001` — never by succeeding emptily. This parser reads a single
  # level, so both shapes of « nothing readable » show at its own depth.
  it 'refuses a list of objects of which none carries the slot looked for' do
    renamed = body.gsub('name="Requirement"', 'name="Autre"')

    expect { described_class.new(renamed) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  it 'refuses a success carrying no object at all' do
    emptied = body.sub(%r{<rim:RegistryObjectList>.*</rim:RegistryObjectList>}m, '<rim:RegistryObjectList/>')

    expect { described_class.new(emptied) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  it 'names the requirement in each language the directory publishes' do
    requirement = described_class.new(body).requirements.first

    expect(requirement.descriptions).to include('EN' => '(TEST) Test Requirement', 'FI' => 'Testivaatimus')
    expect(requirement.details['EN']).to start_with('Member States may assign their own Evidence Types')
  end

  # The declaration is what a member state publishes to say one of its own
  # procedures rests on this requirement. France maps its `00` onto the
  # Commission's smoke-test requirement.
  it 'reads the procedures declaring the requirement' do
    declared = described_class.new(body).requirements.first.reference_frameworks

    expect(declared.map(&:procedure_code)).to eq(['00'])
    expect(declared.first)
      .to have_attributes(id: '92c27c13-5c49-439b-a334-683d736a0cb7', country: 'FR')
    expect(declared.first.descriptions).to eq('EN' => 'Test - FR - MS Procedure')
  end

  # Walking from a declaration back to what it rests on is what a listing of
  # procedures does, the directory publishing the graph the other way round.
  it 'lets a declaration name the requirement carrying it' do
    requirement = described_class.new(body).requirements.first

    expect(requirement.reference_frameworks.first.requirement).to be(requirement)
  end

  # Unlike the identifier above, and deliberately: this reading is on the path
  # of every real request, where refusing would turn one unplaceable line of a
  # catalogue into a failed exchange.
  it 'tolerates a declaration published without a procedure code' do
    stripped = body.sub(%r{<sdg:RelatedTo>.*?</sdg:RelatedTo>}m, '')

    expect(described_class.new(stripped).requirements.first.reference_frameworks.first.procedure_code).to be_nil
  end

  # Every parameter of this query is optional, so the same parser reads the
  # answer to a query carrying none: everything the directory holds.
  describe 'the whole catalogue' do
    subject(:requirements) { described_class.new(common_services_answer('eb_requirements_catalogue').first).requirements }

    it 'reads every requirement the directory publishes' do
      expect(requirements.size).to eq(53)
    end

    it 'reads every declaration made under them' do
      expect(requirements.sum { |found| found.reference_frameworks.size }).to eq(687)
    end

    # One requirement is cited by dozens of procedures across the Union, which
    # is the whole reason the catalogue is worth listing.
    it 'reads a requirement cited by many member states' do
      shared = requirements.max_by { |found| found.reference_frameworks.size }

      expect(shared.countries.size).to be > 20
      expect(shared.procedure_codes.size).to be > 1
    end
  end
end
