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
end
