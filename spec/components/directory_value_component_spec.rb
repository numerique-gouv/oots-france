require 'rails_helper'

RSpec.describe DirectoryValueComponent, type: :component do
  it 'marks what it is given as published elsewhere' do
    render_inline(described_class.new) { 'Proof of enrolment in academic tertiary education' }

    expect(page).to have_css('span.directory-value', text: 'Proof of enrolment in academic tertiary education')
  end

  # A tint says it to the eye only, which RGAA 3.1 refuses: the meaning has to
  # be in the text, and it rides the tooltip for whoever hovers it.
  it 'writes out what the tint means, off screen and as a tooltip' do
    render_inline(described_class.new) { 'peu importe' }

    wording = I18n.t('components.directory_value.label', raise: true)

    expect(page).to have_css('.directory-value .fr-sr-only', text: wording)
    expect(page).to have_css(".directory-value[title='#{wording}']")
  end

  # RGAA 8.7: a passage in another language than the page's carries its own
  # `lang`, failing which a screen reader pronounces English as French.
  it 'declares the language the directory published the wording in' do
    render_inline(described_class.new(lang: 'EN')) { 'Apply for funding for higher education' }

    expect(page).to have_css(".directory-value[lang='EN']")
  end

  # The console reads the directories in French wherever they publish one, so a
  # wording in the page's own language carries no `lang` to declare.
  it 'declares none when the caller knows of none' do
    render_inline(described_class.new) { 'peu importe' }

    expect(page.native.at_css('.directory-value')['lang']).to be_blank
  end

  # These wordings come from a directory, which is not this deployment. Nothing
  # here escapes them — ViewComponent renders through ActionView, which does —
  # so what this holds shut is a later `raw` or `html_safe` on the way in.
  it 'escapes a wording a directory published' do
    render_inline(described_class.new) { '<script>alert(1)</script>' }

    expect(page.native.to_html).to include('&lt;script&gt;')
    expect(page).to have_no_css('script')
  end
end
