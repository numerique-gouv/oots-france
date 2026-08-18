require 'rails_helper'

RSpec.describe CardComponent, type: :component do
  it 'names the entry, and links it when there is somewhere to go' do
    render_inline(described_class.new(title: 'R1', href: '/admin/common_services/procedures/R1'))

    expect(page).to have_css(".fr-card__title a[href='/admin/common_services/procedures/R1']", text: 'R1')
  end

  it 'names the entry plainly when there is nowhere to go' do
    render_inline(described_class.new(title: 'FR'))

    expect(page).to have_css('.fr-card__title', text: 'FR')
    expect(page).to have_no_css('.fr-card__title a')
  end

  # What describes the entry and what hangs off it are not the same thing to
  # read: the second sits below a rule of its own.
  it 'sets what it lists apart from what describes it' do
    render_inline(described_class.new(title: 'FI')) do |carte|
      carte.with_list { '<table></table>'.html_safe }
      'Un service'
    end

    expect(page).to have_css('.fr-card__desc', text: 'Un service')
    expect(page).to have_css('.card-list table')
  end

  it 'leaves out both sections when it carries neither' do
    render_inline(described_class.new(title: 'FR'))

    expect(page).to have_no_css('.fr-card__desc')
    expect(page).to have_no_css('.card-list')
  end
end
