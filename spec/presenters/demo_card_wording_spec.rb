require 'rails_helper'

RSpec.describe DemoCardWording do
  def type(title, lang = 'EN')
    build(:evidence_type, id: "https://sr/EL/#{title.parameterize}", descriptions: { lang => title })
  end

  def list(*types, names: {}) = build(:evidence_type_list, evidence_types: types, descriptions: names)

  # RG1 of OOTS-270: what the list « Document to request » calls each
  # combination.
  describe '.label' do
    it 'names a combination of one type by that type' do
      combination = list(type('Simple test evidence'), names: { 'EN' => 'Simple' })

      expect([described_class.label(combination), described_class.label_language(combination)])
        .to eq(['Simple test evidence', 'EN'])
    end

    it 'names a combination of several by the name the Evidence Broker gives it, in the language of the page first' do
      combination = list(type('Projectathon test evidence'), type('Simple test evidence'),
        names: { 'FR' => 'Justificatif composé', 'EN' => 'Compound test evidence' })

      expect([described_class.label(combination), described_class.label_language(combination)])
        .to eq(['Justificatif composé', 'FR'])
    end

    it 'names it by its English name on a page read in English' do
      combination = list(type('Projectathon test evidence'), type('Simple test evidence'),
        names: { 'FR' => 'Justificatif composé', 'EN' => 'Compound test evidence' })

      I18n.with_locale(:en) do
        expect([described_class.label(combination), described_class.label_language(combination)])
          .to eq(['Compound test evidence', 'EN'])
      end
    end

    it 'joins the titles of its types, in the order of the list, where it has no name in English or French' do
      combination = list(type('A'), type('B'), type('C'), names: { 'EL' => 'Σύνθετο' })

      expect(described_class.label(combination)).to eq('A, B et C')
    end

    it 'names a combination of several by its English name where it has no French one' do
      expect(described_class.label(list(type('B'), type('C'), names: { 'EN' => 'Compound' }))).to eq('Compound')
    end

    # RGAA 8.7: the « and » that joins them is in the language of the page.
    it 'declares the language of the page for titles joined from that language alone' do
      expect(described_class.label_language(list(type('A', 'FR'), type('B', 'FR')))).to eq('FR')

      I18n.with_locale(:en) do
        expect(described_class.label_language(list(type('A'), type('B')))).to eq('EN')
      end
    end

    it 'declares no language for titles joined from another language than the page\'s' do
      expect(described_class.label_language(list(type('A'), type('B')))).to be_nil
      expect(described_class.label_language(list(type('B', 'FR'), type('Γ', 'EL')))).to be_nil
      expect(described_class.label_language(list(type('Β', 'EL'), type('Γ', 'EL')))).to be_nil
    end
  end

  describe 'a combination resolved' do
    subject(:wording) { described_class.new(lookup) }

    let(:combination) { list(type('B'), type('C')) }
    let(:lookup) do
      Interactor::Context.new(requirement: build(:requirement), country_code: 'EL', evidence_type_list: combination,
        evidence_type_lists: [combination, list(type('A'))], lines:)
    end
    let(:lines) do
      combination.evidence_types.map do |each|
        Interactor::Context.new(evidence_type: each, data_services: [build(:data_service)])
      end
    end

    it 'names a line per type, and is nameable once every line is' do
      expect(wording.lines.map(&:evidence_type)).to eq(%w[B C])
      expect(wording).to be_nameable
      expect(wording).to be_choosable
    end

    it 'offers no choice where the country publishes a single combination' do
      lookup.evidence_type_lists = [combination]

      expect(wording).not_to be_choosable
    end

    it 'is not nameable without a line' do
      lookup.lines = []

      expect(wording).not_to be_nameable
    end

    # Requirement 27 of chapter 1 §2: every type named before any request.
    it 'is not nameable while a line names no provider' do
      lines.last.data_services = []

      expect(wording).not_to be_nameable
    end
  end
end
