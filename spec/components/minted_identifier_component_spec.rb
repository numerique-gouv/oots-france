require 'rails_helper'

RSpec.describe MintedIdentifierComponent, type: :component do
  let(:meaning) { I18n.t('components.minted_identifier.meaning') }

  it 'marks the identifier of an exchange conducted on the 1.2 line' do
    render_inline(described_class.new(exchange: build(:exchange, :legacy_line)))

    expect(page).to have_css('.fr-badge', text: I18n.t('components.minted_identifier.label'))
  end

  # The label alone could be read as saying the exchange never happened: the
  # meaning is what lifts that, and it reaches both a pointer and a reader.
  it 'gives its meaning to whoever hovers and to whoever listens' do
    render_inline(described_class.new(exchange: build(:exchange, :legacy_line)))

    expect(page).to have_css(".fr-badge[title='#{meaning}']")
    expect(page).to have_css('.fr-badge .fr-sr-only', text: meaning)
  end

  # Phrasing content, so that the mark can follow the identifier into the `<h1>`
  # of an exchange and the `<h2>` of its block on a conversation page.
  it 'renders as phrasing content, which a heading admits' do
    render_inline(described_class.new(exchange: build(:exchange, :legacy_line)))

    expect(page).to have_css('span.fr-badge')
    expect(page).to have_no_css('div.fr-badge')
  end

  it 'says nothing of an exchange whose header names it' do
    render_inline(described_class.new(exchange: build(:exchange)))

    expect(page).to have_no_css('.fr-badge')
  end

  it 'says nothing of an exchange whose version was never settled' do
    render_inline(described_class.new(exchange: build(:exchange, :unsettled_line)))

    expect(page).to have_no_css('.fr-badge')
  end

  # An event may name an exchange France never opened: there is then nothing to
  # ask, and nothing to warn of.
  it 'says nothing where there is no exchange at all' do
    render_inline(described_class.new(exchange: nil))

    expect(page).to have_no_css('.fr-badge')
  end
end
