require 'rails_helper'

RSpec.describe PaginationComponent, type: :component do
  def component(current:, pages:)
    described_class.new(current:, pages:, link: ->(page) { "/admin/journal/conversations?page=#{page}" })
  end

  describe '#render?' do
    it 'renders nothing when everything fits on one page' do
      expect(component(current: 1, pages: 1).render?).to be(false)
    end
  end

  describe '#numbers' do
    it 'keeps the first and last page around the window' do
      expect(component(current: 10, pages: 20).numbers).to eq([1, 8, 9, 10, 11, 12, 20])
    end

    it 'stays within the bounds' do
      expect(component(current: 1, pages: 3).numbers).to eq([1, 2, 3])
    end
  end

  describe 'the two ends' do
    it 'offers no previous page on the first' do
      expect(component(current: 1, pages: 5).previous_page).to be_nil
    end

    it 'offers no next page on the last' do
      expect(component(current: 5, pages: 5).next_page).to be_nil
    end

    it 'surrounds a page in the middle' do
      built = component(current: 3, pages: 5)

      expect([built.previous_page, built.next_page]).to eq([2, 4])
    end
  end

  describe 'rendering' do
    it 'marks the current page for whoever cannot see it' do
      render_inline(component(current: 2, pages: 5))

      expect(page).to have_css("a[aria-current='page']", text: '2')
    end

    it 'disables the end it cannot go to, rather than linking nowhere' do
      render_inline(component(current: 1, pages: 5))

      expect(page).to have_css("span[aria-disabled='true']", text: 'Page précédente')
      expect(page).to have_css('a', text: 'Page suivante')
    end
  end
end
