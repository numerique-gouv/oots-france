require 'rails_helper'

RSpec.describe DeferredContentComponent, type: :component do
  subject(:place) do
    described_class.new(url: '/admin/common_services/requirements?listing=1',
      message: 'Chargement de toutes les exigences publiées, veuillez patienter.')
  end

  it 'hands the browser the address to fetch and the sentence to show meanwhile' do
    render_inline(place)

    element = page.find('[data-controller="deferred"]', visible: :all)

    expect(element['data-deferred-url-value']).to eq('/admin/common_services/requirements?listing=1')
    expect(page).to have_text('Chargement de toutes les exigences publiées, veuillez patienter.')
  end

  # Whoever cannot see the spinner is otherwise told nothing at all.
  it 'announces the wait rather than only drawing it' do
    render_inline(place)

    expect(page).to have_css('[role="status"]', text: 'Chargement de toutes les exigences')
    expect(page).to have_css('.deferred-content__spinner[aria-hidden="true"]', visible: :all)
  end

  # Its animation is pure CSS: rendered visible, it would spin for ever beside
  # the `<noscript>` sentence. Whatever is going to make it stop reveals it.
  it 'leaves the spinner hidden until the controller that stops it connects' do
    render_inline(place)

    expect(page).to have_css('.deferred-content__spinner[hidden]', visible: :all)
    expect(page.find('.deferred-content__spinner', visible: :all)['data-deferred-target']).to eq('spinner')
  end

  # A failure is written into the paragraph, never over it: replacing the
  # element would take the `role="status"` with it, and the sentence would
  # arrive where nothing reads it out.
  it 'keeps the announced region around the sentence a failure will replace' do
    render_inline(place)

    announced = page.find('[role="status"]')

    expect(announced).to have_css('[data-deferred-target="message"]',
      text: 'Chargement de toutes les exigences publiées, veuillez patienter.')
  end

  # The failure has no page of its own: only a request that never reached the
  # server lands there, and it left nothing to render.
  it 'carries the wording of a failure the browser alone will see' do
    render_inline(place)

    expect(page.find('[data-controller="deferred"]', visible: :all)['data-deferred-failed-value'])
      .to eq(I18n.t('components.deferred_content.failed'))
  end

  it 'says in the page itself that its content needs JavaScript' do
    render_inline(place)

    expect(page.native.to_html).to include('<noscript>')
    expect(page.native.to_html).to include(I18n.t('components.deferred_content.no_script'))
  end
end
