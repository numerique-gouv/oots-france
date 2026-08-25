require 'rails_helper'

RSpec.describe DecryptedValueComponent, type: :component do
  it 'marks with an open padlock what it is given' do
    render_inline(described_class.new) { '<code>dupont|sophie|1965-11-25</code>'.html_safe }

    expect(page).to have_css('.decrypted-value .fr-icon-lock-unlock-line[aria-hidden="true"]')
    expect(page).to have_css('.decrypted-value code', text: 'dupont|sophie|1965-11-25')
  end

  # A screen reader is told to skip the padlock, so a mark nobody can read is no
  # mark at all: the meaning has to be in the text beside it.
  it 'writes out what the padlock means, off screen and as a tooltip' do
    render_inline(described_class.new) { 'peu importe' }

    wording = I18n.t('components.decrypted_value.label', raise: true)

    expect(page).to have_css('.fr-sr-only', text: wording)
    expect(page).to have_css(".decrypted-value__icon[title='#{wording}']")
  end

  # A folded document is a `<div>`, and `<span>` takes phrasing content only:
  # the inline wrapper would make the markup invalid around the one column that
  # needs it most.
  it 'wraps a block value in a block of its own' do
    render_inline(described_class.new(block: true)) { '<div>un document</div>'.html_safe }

    expect(page).to have_css('div.decrypted-value.decrypted-value--block div', text: 'un document')
  end

  it 'stays inline for everything else' do
    render_inline(described_class.new) { 'peu importe' }

    expect(page).to have_css('span.decrypted-value')
    expect(page).to have_no_css('.decrypted-value--block')
  end

  # `evidence_subject` carries the name a foreign correspondent wrote. Nothing
  # here escapes it — ViewComponent renders through ActionView, which does — so
  # what this holds shut is a later `raw` or `html_safe` on the way in.
  it 'escapes a value a correspondent chose' do
    render_inline(described_class.new) { '{"family_name":"<script>alert(1)</script>"}' }

    expect(page.native.to_html).to include('&lt;script&gt;')
    expect(page).to have_no_css('script')
  end
end
