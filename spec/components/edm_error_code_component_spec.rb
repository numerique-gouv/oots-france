require 'rails_helper'

RSpec.describe EdmErrorCodeComponent, type: :component do
  it 'says in French every code the specification defines' do
    EdmException::ALL.each do |exception|
      render_inline(described_class.new(code: exception.code))

      expect(page).to have_text(I18n.t("components.edm_error_code.codes.#{exception.code}", raise: true))
    end
  end

  it 'links the code to the chapter that defines it' do
    render_inline(described_class.new(code: 'EDM:ERR:0005'))

    expect(page).to have_link('EDM:ERR:0005', href: described_class::CHAPTER_URL)
    expect(page).to have_text("Délai d'expiration dépassé")
  end

  # The eight are a closed list, and a correspondent is free not to honour it.
  # Pointing that link at a code the chapter does not carry would claim it says
  # something it does not.
  it 'shows a code outside the eight bare, without a link' do
    render_inline(described_class.new(code: 'XX:ERR:9999'))

    expect(page).to have_text('XX:ERR:9999')
    expect(page).to have_no_link
  end
end
