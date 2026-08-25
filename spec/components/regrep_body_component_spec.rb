require 'rails_helper'

RSpec.describe RegrepBodyComponent, type: :component do
  let(:body) { '<query:QueryRequest id="urn:uuid:cdd87e02"/>' }

  it 'folds the document behind a button that names its size' do
    render_inline(described_class.new(body:))

    button = page.find("button[aria-controls='#{described_class::REGION_ID}']")

    expect(button[:'aria-expanded']).to eq('false')
    expect(button.text).to include(ActiveSupport::NumberHelper.number_to_human_size(body.bytesize))
  end

  # A box one can only scroll with a pointer fails WCAG 2.1.1, and a focusable
  # region with no name says nothing to whoever lands on it.
  it 'gives the scrolling region a name and a way in from the keyboard' do
    render_inline(described_class.new(body:))

    region = page.find('.regrep-body__content')

    expect(region[:tabindex]).to eq('0')
    expect(region[:'aria-label']).to be_present
  end

  it 'renders the document as it circulated' do
    render_inline(described_class.new(body:))

    expect(page).to have_css('pre code', text: body)
  end

  # The bytes are a correspondent's. ViewComponent renders through ActionView,
  # which escapes; what this holds shut is a later `raw` on the way in.
  it 'escapes what the correspondent sent' do
    render_inline(described_class.new(body: '<script>alert(1)</script>'))

    expect(page.native.to_html).to include('&lt;script&gt;')
    expect(page).to have_no_css('script')
  end
end
