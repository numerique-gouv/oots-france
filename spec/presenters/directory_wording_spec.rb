require 'rails_helper'

RSpec.describe DirectoryWording do
  subject(:wording) { described_class.new(names:, articles:, procedures:) }

  let(:names) { { 'BE' => 'Belgique (la)', 'CY' => 'Chypre' } }
  let(:articles) { { 'BE' => 'la' } }
  let(:procedures) { { '00' => 'Vérification système' } }

  # A heading cannot carry a label, so a country is named there as the component
  # names it anywhere else — flag, name, code.
  it 'names a country as the country tag does' do
    expect(wording.named_country('BE')).to eq('🇧🇪 Belgique (la) (BE)')
  end

  # A country the code list does not name is still a country: the catalogue is
  # published by the member states and the list by the Commission, so one names
  # what the other may not.
  it 'names an unlisted country by its code alone' do
    expect(wording.named_country('ZZ')).to eq('🇿🇿 ZZ')
  end

  # The flag alone: the country is named in the breadcrumb just above.
  it 'flags a subject without repeating the country' do
    expect(wording.flagged('BE', 'Justificatif de domicile')).to eq('🇧🇪 Justificatif de domicile')
  end

  # Nothing shaped like a country code yields no flag, and the subject stands
  # alone rather than behind two boxed letters.
  it 'leaves a subject alone when the code forms no flag' do
    expect(wording.flagged(nil, 'Justificatif de domicile')).to eq('Justificatif de domicile')
  end

  # The three that `CountryWording` answers are relayed with its agreement, not
  # with one guessed here.
  it 'places a country the way its article demands' do
    expect([wording.in_country('BE'), wording.in_country('CY')]).to eq(['en Belgique (la)', 'à Chypre'])
  end

  it 'names a country plainly, for an ordering that shows no flag' do
    expect([wording.named_or_code('BE'), wording.named_or_code('ZZ')]).to eq(['Belgique (la)', 'ZZ'])
  end

  # The directory publishes the code alone; the wording lives in the code list,
  # and the rule that joins them belongs to the component.
  it 'names a procedure as the procedure component does' do
    expect(wording.named_procedure('00')).to eq(ProcedureComponent.label('00', 'Vérification système'))
  end

  it 'names a procedure the code list does not word' do
    expect(wording.named_procedure('ZZ')).to eq(ProcedureComponent.label('ZZ', nil))
  end

  # A heading has the room a listing has not, hence the two.
  it 'spells a procedure out in full where a heading asks for it' do
    expect(wording.full_named_procedure('00')).to eq(ProcedureComponent.label('00', 'Vérification système', limit: nil))
  end

  it 'hints at a procedure as the component does' do
    expect(wording.procedure_hint('00')).to eq(ProcedureComponent.hint('Vérification système'))
  end

  it 'summarises a declaration as the country wording words it' do
    expect(wording.declaration_summary(labels: ['Bourse'], country: 'BE', requirements: 2))
      .to eq(CountryWording.new(names:, articles:).declaration(labels: ['Bourse'], country: 'BE', requirements: 2))
  end
end
