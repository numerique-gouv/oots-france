require 'rails_helper'

RSpec.describe CountryTagListComponent, type: :component do
  # A row that wraps, so that twenty countries read as a set rather than as a
  # sentence.
  it 'lays the countries out in a row, each named' do
    render_inline(described_class.new(codes: %w[FR FI], names: { 'FR' => 'France', 'FI' => 'Finlande' }))

    expect(page).to have_css('ul.country-tag-list li span.country-tag', count: 2)
    expect(page).to have_css('.country-tag', text: 'Finlande (FI)')
  end

  it 'leads somewhere when the caller says where' do
    render_inline(described_class.new(codes: %w[FI], names: { 'FI' => 'Finlande' },
      link: ->(code) { "/admin/common_services/procedures/00/country/#{code}" }))

    expect(page).to have_link(count: 1, href: '/admin/common_services/procedures/00/country/FI')
  end

  # A tag reads as a state or a filter, never as somewhere to go; the absence of
  # an address has to be visible too.
  it 'is a plain box, not a link, when the caller gives no address' do
    render_inline(described_class.new(codes: %w[FR], names: { 'FR' => 'France' }))

    expect(page).to have_no_link
    expect(page).to have_css('span.country-tag')
  end

  # The same code twice is one code: what a reader counts here is jurisdictions,
  # not declarations.
  it 'shows a code once, in order' do
    render_inline(described_class.new(codes: ['FR', 'FI', 'FR', nil, '']))

    expect(page.all('.country-tag').map { |box| box.text.split.last }).to eq(%w[FI FR])
  end

  # Au pied d'une carte, la rangée a quitté la phrase qui l'introduisait : sa
  # légende dit en quelle qualité ces pays y figurent.
  it 'says in what capacity the countries appear, when the caller says it' do
    render_inline(described_class.new(codes: %w[FI], caption: 'Démarche déclarée par'))

    expect(page).to have_css('p', text: 'Démarche déclarée par')
  end

  it 'opens straight on the row when the caller has nothing to say' do
    render_inline(described_class.new(codes: %w[FI]))

    expect(page).to have_no_css('p')
  end

  it 'renders nothing at all rather than an empty row' do
    render_inline(described_class.new(codes: []))

    expect(page).to have_no_css('ul')
  end

  describe CountryTagComponent do
    it 'flies the flag of a country, and names it first' do
      render_inline(described_class.new(code: 'AT', name: 'Autriche'))

      expect(page).to have_css('.country-tag', text: '🇦🇹 Autriche (AT)')
    end

    describe '.label' do
      # A heading, a breadcrumb and an option of the filter carry no box, so the
      # rule lives once and every rendering shares it.
      it 'says a country the same way wherever one appears' do
        expect(described_class.label('FI', 'Finlande')).to eq('🇫🇮 Finlande (FI)')
        expect(described_class.label('FI')).to eq('🇫🇮 FI')
        expect(described_class.label(nil)).to eq('—')
      end

      # The directories name Greece after the convention of the institutions,
      # the flag sequences after ISO 3166-1; unmapped, `EL` forms no flag.
      it 'flies the flag ISO 3166-1 gives a country the directories name otherwise' do
        expect(described_class.label('EL', 'Grèce')).to eq('🇬🇷 Grèce (EL)')
        expect(described_class.label('UK', 'Royaume-Uni')).to eq('🇬🇧 Royaume-Uni (UK)')
      end

      # Anything else would render as two unrelated letters under a flag.
      it 'flies no flag over something that is not shaped like a country code' do
        expect(described_class.label('ZZZ', 'Nulle part')).to eq('Nulle part (ZZZ)')
      end
    end
  end
end
