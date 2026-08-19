require 'rails_helper'

RSpec.describe SlotReading do
  # `require_content` names what is missing with a key rather than a sentence,
  # so nothing static ties the parsers to their wordings: `i18n-tasks` reads
  # neither side of a key it never sees written as a lookup.
  it 'says every key its parsers write' do
    written = Dir['app/parsers/**/*.rb']
      .flat_map { |path| File.read(path).scan(/'(parsers(?:\.[a-z_]+)+)'/) }
      .flatten.uniq

    expect_said(written)
  end

  # `R-EDM-REQ-C073` n'impose de l'adresse d'un agent que le pays, et les
  # fixtures de référence l'écrivent toutes en majuscules : ce que fait la
  # lecture d'un correspondant moins soigneux ne se voit que d'ici.
  describe 'the country an agent declares' do
    let(:reader) do
      Class.new {
        include SlotReading

        public :agent_country
      }.new
    end

    def agent(country)
      inner = country.nil? ? '' : "<sdg:Address><sdg:AdminUnitLevel1>#{country}</sdg:AdminUnitLevel1></sdg:Address>"

      Nokogiri::XML(<<~XML).root
        <sdg:Agent xmlns:sdg="#{OotsNamespaces::NAMESPACES.fetch('sdg')}">#{inner}</sdg:Agent>
      XML
    end

    it 'upcases what a correspondent wrote in lower case' do
      expect(reader.agent_country(agent('fr'))).to eq('FR')
    end

    it 'keeps a code already written as one' do
      expect(reader.agent_country(agent('BE'))).to eq('BE')
    end

    # Stocké tel quel, il ne répondrait jamais à un filtre par pays — le journal
    # garde ce qu'il a pu lire, et rien de ce qu'il ne peut pas relire.
    it 'drops what is not shaped like a country code' do
      expect(reader.agent_country(agent('France'))).to be_nil
    end

    it 'drops an address the message never carried' do
      expect(reader.agent_country(agent(nil))).to be_nil
    end
  end
end
