require 'rails_helper'

RSpec.describe ExchangeStatusComponent, type: :component do
  it 'gives a colour to every state the model has' do
    expect(Exchange::STATUSES - described_class::BADGES.keys).to be_empty
  end

  it 'reads a failure as an error' do
    expect(described_class::BADGES['failed']).to eq(:error)
  end

  it 'reads an exchange no evidence matched as a warning' do
    render_inline(described_class.new(exchange: build(:exchange, status: 'unmatched')))

    expect(page).to have_css('.fr-badge.fr-badge--warning', text: 'Aucun justificatif')
  end

  it 'renders the state in French, in a DSFR badge' do
    render_inline(described_class.new(exchange: build(:exchange, status: 'delivered')))

    expect(page).to have_css('.fr-badge.fr-badge--success', text: 'Délivré')
  end

  # `default:` lets an unknown state through, and would let a missing wording
  # through just as quietly — the badge would read `pending` rather than fail.
  it 'says every state the model has in French' do
    Exchange::STATUSES.each do |status|
      render_inline(described_class.new(exchange: build(:exchange, status:, incoming: true)))

      expect(page).to have_css('.fr-badge', text: I18n.t("admin.journal.exchanges.statuses.#{status}", raise: true))
    end
  end

  # An exchange the console does not recognise still has to appear: this page
  # is consulted when something has gone wrong, and is the wrong place to fail.
  it 'shows a state it does not know rather than failing' do
    render_inline(described_class.new(exchange: build(:exchange, status: 'inconnu')))

    expect(page).to have_css('.fr-badge', text: 'inconnu')
  end

  # The empty list answers a refusal and an absence alike (chapter 4.9 §1):
  # France, requesting, cannot say which.
  it 'says of an outgoing exchange declined only that no evidence came after the preview' do
    render_inline(described_class.new(exchange: build(:exchange, status: 'declined', incoming: false)))

    expect(page).to have_css('.fr-badge', text: 'Aucun justificatif après prévisualisation')
  end

  it 'says it in English when the reader chose English' do
    I18n.with_locale(:en) do
      render_inline(described_class.new(exchange: build(:exchange, status: 'declined', incoming: false)))
    end

    expect(page).to have_css('.fr-badge', text: 'No evidence after preview')
  end

  it 'says of an incoming exchange declined that the user refused' do
    render_inline(described_class.new(exchange: build(:exchange, status: 'declined', incoming: true)))

    expect(page).to have_css('.fr-badge', text: "Refusé par l'usager")
  end
end
