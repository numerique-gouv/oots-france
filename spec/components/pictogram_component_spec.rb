require 'rails_helper'

RSpec.describe PictogramComponent, type: :component do
  it 'renders the artwork the distribution ships, under the digest Propshaft gives it' do
    render_inline(described_class.new(name: 'digital/avatar'))

    expect(page.find('img.pictogram', visible: :all)[:src]).to match(%r{/assets/artwork/pictograms/digital/avatar-\w+\.svg})
  end

  it 'says nothing, the wording beside it naming what it depicts' do
    render_inline(described_class.new(name: 'document/document-download'))

    image = page.find('img.pictogram', visible: :all)
    expect(image[:alt]).to eq('')
    expect(image[:'aria-hidden']).to eq('true')
  end
end
