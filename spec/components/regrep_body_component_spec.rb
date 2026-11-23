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

  describe 'a document sent on one line' do
    let(:body) do
      '<?xml version="1.0" encoding="UTF-8"?><query:QueryRequest xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0" ' \
        'xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0" id="urn:uuid:cdd87e02"><!-- sent by BE -->' \
        '<rim:Slot name="SpecificationIdentifier"><rim:SlotValue><rim:Value>oots-edm:v1.2</rim:Value></rim:SlotValue>' \
        '</rim:Slot></query:QueryRequest>'
    end

    def shown(body) = render_inline(described_class.new(body:)).at_css('pre code').text

    it 'shows one element per line, each indented under its parent' do
      expect(shown(body).lines.map(&:chomp)).to eq(
        ['<?xml version="1.0" encoding="UTF-8"?>',
         body[/<query:QueryRequest [^>]*>/],
         '  <!-- sent by BE -->',
         '  <rim:Slot name="SpecificationIdentifier">',
         '    <rim:SlotValue>',
         '      <rim:Value>oots-edm:v1.2</rim:Value>',
         '    </rim:SlotValue>',
         '  </rim:Slot>',
         '</query:QueryRequest>']
      )
    end

    # What the page shows is the document that travelled: the same names under
    # the same prefixes and namespaces, the same attributes, texts and comments.
    it 'shows the same document as the one kept' do
      read = ->(xml) { Nokogiri::XML(xml, &:noblanks) }
      tree = lambda do |node|
        [node.class, node.name, node.try(:namespace)&.prefix, node.try(:namespace)&.href,
         node.try(:attribute_nodes)&.map { [it.name, it.value] }, (node.content if node.text? || node.comment?),
         node.children.map(&tree)]
      end

      expect(tree.call(read.call(shown(body)).root)).to eq(tree.call(read.call(body).root))
    end

    it 'says it was indented for reading, in the language of the page' do
      render_inline(described_class.new(body:))
      expect(page).to have_text("Indenté pour la lecture. Le journal conserve le message tel qu'il a circulé.")

      I18n.with_locale(:en) { render_inline(described_class.new(body:)) }
      expect(page).to have_text('Indented for reading. The journal keeps the message as it travelled.')
    end

    it 'announces the size that circulated, not that of what is shown' do
      render_inline(described_class.new(body:))

      expect(page.find('button').text).to include(ActiveSupport::NumberHelper.number_to_human_size(body.bytesize))
      expect(shown(body).bytesize).not_to eq(body.bytesize)
    end

    it 'adds no declaration the document did not make' do
      expect(shown(body.delete_prefix('<?xml version="1.0" encoding="UTF-8"?>'))).not_to include('<?xml')
    end

    it 'reads a declaration of UTF-8 whatever its case and quotes' do
      expect(shown("<?xml version='1.0' encoding='utf-8'?><a><b>BE</b></a>")).to include("\n  <b>BE</b>\n")
    end

    it 'keeps the declaration a byte order mark precedes' do
      expect(shown("\uFEFF<?xml version=\"1.0\" encoding=\"UTF-8\"?><a><b>BE</b></a>"))
        .to eq(%(<?xml version="1.0" encoding="UTF-8"?>\n<a>\n  <b>BE</b>\n</a>\n))
    end

    it 'shows the characters it carries, not references to them' do
      expect(shown('<a><b>café — Liège</b></a>')).to include("\n  <b>café — Liège</b>\n")
    end

    # A later `noent` or `dtdload` would turn the page into a way of reading the
    # server's files, or of expanding what a correspondent declared.
    it 'neither fetches nor expands an entity the document declares' do
      external = '<!DOCTYPE a [<!ENTITY x SYSTEM "file:///etc/hostname">]><a><b>&x;</b></a>'
      internal = '<!DOCTYPE a [<!ENTITY y "boom">]><a><b>&y;</b></a>'

      expect(shown(external)).to include('<b>&x;</b>')
      expect(shown(internal)).to include('<b>&y;</b>')
    end

    it 'leaves mixed content as it is written' do
      expect(shown('<a><p>one <b>two</b> three</p></a>')).to eq("<a>\n  <p>one <b>two</b> three</p>\n</a>\n")
    end

    it 'keeps escaped what a well-formed document carries as text' do
      render_inline(described_class.new(body: '<a><b>&lt;script&gt;alert(1)&lt;/script&gt;</b></a>'))

      expect(page.native.to_html).to include('&amp;lt;script&amp;gt;')
      expect(page).to have_no_css('script')
    end
  end

  # Each of these is shown as kept, and says nothing of an indentation it did
  # not get.
  {
    'a document that is not well-formed' => '<query:QueryRequest><rim:Slot></query:QueryRequest>',
    'a document with an undeclared prefix' => '<query:QueryRequest id="urn:uuid:cdd87e02"/>',
    'a document declaring another encoding' => '<?xml version="1.0" encoding="ISO-8859-1"?><a><b>café</b></a>',
    'bytes that are not valid UTF-8' => (+"<a><b>\xE9</b></a>").force_encoding(Encoding::UTF_8),
    'a document declaring another encoding after a byte order mark' =>
      "\uFEFF<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><a><b>BE</b></a>"
  }.each do |what, kept|
    it "shows #{what} as it is kept" do
      render_inline(described_class.new(body: kept))

      expect(page.find('pre code').text).to eq(kept.scrub)
      expect(page).to have_no_text(I18n.t('components.regrep_body.indented'))
    end
  end

  # The bytes are a correspondent's. ViewComponent renders through ActionView,
  # which escapes; what this holds shut is a later `raw` on the way in.
  it 'escapes what the correspondent sent' do
    render_inline(described_class.new(body: '<script>alert(1)</script>'))

    expect(page.native.to_html).to include('&lt;script&gt;')
    expect(page).to have_no_css('script')
  end
end
