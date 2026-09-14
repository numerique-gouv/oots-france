require 'rails_helper'

RSpec.describe DemoProcedureWording do
  subject(:wording) { described_class.new(code: 'T1', requirements:, published_name:, published_name_language:) }

  let(:published_name) { 'Applying for a tertiary education study financing' }
  let(:published_name_language) { 'en' }
  let(:declared) do
    ReferenceFramework.new(procedure_code: 'T1', country: 'FR',
      descriptions: { 'EN' => 'Apply for funding for higher education' })
  end
  let(:requirements) { [Requirement.new(reference_frameworks: [declared])] }

  # A member state names its own procedure, and that name is what its portal
  # would show. Marked with the language the directory published it in, so that
  # a screen reader does not pronounce one as the other (RGAA 8.7).
  it 'stands under the title the country declared, in the language it declared it' do
    expect(wording).to have_attributes(title: 'Apply for funding for higher education', title_language: 'EN')
  end

  # The declaration of another member state is not France's: a procedure code is
  # shared across the Union, and the title that goes with it is not.
  context 'when the declaration under that code belongs to another member state' do
    let(:declared) do
      ReferenceFramework.new(procedure_code: 'T1', country: 'DE',
        descriptions: { 'EN' => 'Antrag auf Studienfinanzierung' })
    end

    it 'falls back on the title the code list publishes' do
      expect(wording).to have_attributes(title: published_name, title_language: 'en')
    end
  end

  # The same code list read in another column would be declared English all the
  # same if the language were fixed here rather than received.
  context 'when the caller read the code list in French' do
    let(:published_name) { 'Demander le financement d’études supérieures' }
    let(:published_name_language) { 'fr' }
    let(:declared) { ReferenceFramework.new(procedure_code: 'T1', country: 'DE', descriptions: {}) }

    it 'declares the language the caller read it in' do
      expect(wording).to have_attributes(title: published_name, title_language: 'fr')
    end
  end

  context 'when neither the directory nor the code list names it' do
    let(:published_name) { nil }
    let(:declared) { ReferenceFramework.new(procedure_code: 'T1', country: 'DE', descriptions: {}) }

    it 'has no title, and no language to declare' do
      expect(wording).to have_attributes(title: nil, title_language: nil)
    end
  end
end
