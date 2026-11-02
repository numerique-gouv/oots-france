require 'rails_helper'

RSpec.describe PreviewSessionPresenter do
  # CA8: the size of the document follows the language of the page.
  it 'writes the size of the document in the language of the page' do
    presenter = described_class.new(build(:preview_session, document: Base64.strict_encode64('x' * 1_536)))

    expect(presenter.document_size).to eq('1,5 ko')
    expect(I18n.with_locale(:en) { presenter.document_size }).to eq('1.5 KB')
  end
end
