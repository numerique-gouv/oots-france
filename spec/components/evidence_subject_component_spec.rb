require 'rails_helper'

RSpec.describe EvidenceSubjectComponent, type: :component do
  it 'reads each field under its French wording' do
    render_inline(described_class.new(value: { 'family_name' => 'Königreich', 'given_name' => 'Ada' }))

    expect(page.all('dl.evidence-subject > dt, dl.evidence-subject > dd').map { |node| node.text.strip }).to eq([
      I18n.t('components.evidence_subject.fields.family_name'), 'Königreich',
      I18n.t('components.evidence_subject.fields.given_name'), 'Ada',
    ])
  end

  # What makes the fields chapter 4.5.1 allows and this deployment does not read
  # yet — a nationality, an address — legible the day they are recorded, without
  # anyone having to reopen this. It is also how an identifier scheme reads:
  # `R-EDM-REQ-C055` compares `VAT` to a published list word for word.
  it 'shows under its own name a field no wording translates' do
    render_inline(described_class.new(value: { 'nationality' => 'FR' }))

    expect(page).to have_css('dt', text: 'nationality')
    expect(page).to have_css('dd', text: 'FR')
  end

  # Chapter 4.5.1 has `CurrentAddress` and `RegisteredAddress` structured, and
  # the identifiers of an organisation are a table of their own.
  it 'nests a structured value instead of flattening it' do
    render_inline(described_class.new(value: { 'identifiers' => { 'VAT' => 'FR12345678901' } }))

    expect(page).to have_css('dd > .evidence-subject > dt', text: 'VAT')
    expect(page).to have_css('dd > .evidence-subject > dd', text: 'FR12345678901')
  end

  # `Nationality` is `0..n`, on the natural person of that same chapter.
  it 'lists a repeated value item by item' do
    render_inline(described_class.new(value: { 'nationality' => %w[FR DE] }))

    expect(page.all('ul.evidence-subject__list li').map { |node| node.text.strip }).to eq(%w[FR DE])
  end

  # `Identifier` is `0..n` on the legal person, so what repeats is not always a
  # code: the walk has to meet a list of structures without flattening either.
  it 'nests each item of a repeated structure' do
    render_inline(described_class.new(
      value: { 'identifiers' => [{ 'VAT' => 'FR12345678901' }, { 'LEI' => '969500HBOM1RJXTLZ57' }] },
    ))

    expect(page.all('ul.evidence-subject__list > li > dl.evidence-subject > dt').map { |node| node.text.strip })
      .to eq(%w[VAT LEI])
  end

  # The subject is read off a request a correspondent wrote. ViewComponent
  # renders through ActionView, which escapes; what this holds shut is a later
  # `raw` on the way in.
  it 'escapes what the correspondent sent' do
    render_inline(described_class.new(value: { 'legal_name' => '<script>alert(1)</script>' }))

    expect(page.native.to_html).to include('&lt;script&gt;')
    expect(page).to have_no_css('script')
  end
end
