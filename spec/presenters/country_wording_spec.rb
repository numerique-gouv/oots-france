require 'rails_helper'

RSpec.describe CountryWording do
  subject(:wording) { described_class.new(names:, articles:) }

  let(:names) do
    { 'BE' => 'Belgique (la)', 'LU' => 'Luxembourg (le)', 'NL' => 'Pays-Bas (les)',
      'AT' => 'Autriche (l’)', 'CY' => 'Chypre' }
  end
  let(:articles) { { 'BE' => 'la', 'LU' => 'le', 'NL' => 'les', 'AT' => 'l’' } }

  # The preposition follows the article the code list publishes, never a rule
  # guessed on the name.
  it 'places a country the way its article demands' do
    expect(%w[BE LU NL AT CY].map { |code| wording.in(code) })
      .to eq(['en Belgique (la)', 'au Luxembourg (le)', 'aux Pays-Bas (les)',
              'en Autriche (l’)', 'à Chypre'])
  end

  it 'attributes a declaration the way its article demands' do
    expect(%w[BE LU NL AT CY].map { |code| wording.by(code) })
      .to eq(['par la Belgique (la)', 'par le Luxembourg (le)', 'par les Pays-Bas (les)',
              'par l’Autriche (l’)', 'par Chypre'])
  end

  # The code list is published by the Commission and the catalogue by the member
  # states: nothing guarantees that one names everything the other declares.
  it 'says a country the code list does not name by its code' do
    expect(wording.named('ZZ')).to eq('ZZ')
    expect(wording.by('ZZ')).to eq('par ZZ')
  end

  it 'words what a country declared under a code' do
    expect(wording.declaration(labels: ['Procédure de test'], country: 'BE', requirements: 1))
      .to eq("Démarche déclarée sous l'intitulé « Procédure de test » par la Belgique (la), avec une exigence")
  end

  it 'names every title a country filed, without repeating one' do
    said = wording.declaration(labels: %w[Un Deux Un], country: 'CY', requirements: 4)

    expect(said).to eq('Démarche déclarée sous les intitulés « Un » et « Deux » par Chypre, avec 4 exigences')
  end

  # « avec aucune exigence » is not something one writes.
  it 'says a declaration resting on nothing published rather than counting to zero' do
    expect(wording.declaration(labels: [], country: 'CY', requirements: 0))
      .to eq('Démarche déclarée par Chypre, sans exigence publiée')
  end

  it 'leaves the count out when there is none to give' do
    expect(wording.declaration(labels: [], country: 'CY')).to eq('Démarche déclarée par Chypre')
  end
end
