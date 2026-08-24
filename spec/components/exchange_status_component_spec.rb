require 'rails_helper'

RSpec.describe ExchangeStatusComponent, type: :component do
  it 'gives a colour to every state the model has' do
    expect(Exchange::STATUSES - described_class::BADGES.keys).to be_empty
  end

  it 'reads a failure as an error' do
    expect(described_class::BADGES['failed']).to eq(:error)
  end

  it 'renders the state in French, in a DSFR badge' do
    render_inline(described_class.new(status: 'delivered'))

    expect(page).to have_css('.fr-badge.fr-badge--success', text: 'Délivré')
  end

  # `default:` lets an unknown state through, and would let a missing wording
  # through just as quietly — the badge would read `pending` rather than fail.
  it 'says every state the model has in French' do
    Exchange::STATUSES.each do |status|
      render_inline(described_class.new(status:))

      expect(page).to have_css('.fr-badge', text: I18n.t("admin.journal.exchanges.statuses.#{status}", raise: true))
    end
  end

  # An exchange the console does not recognise still has to appear: this page
  # is consulted when something has gone wrong, and is the wrong place to fail.
  it 'shows a state it does not know rather than failing' do
    render_inline(described_class.new(status: 'inconnu'))

    expect(page).to have_css('.fr-badge', text: 'inconnu')
  end
end
