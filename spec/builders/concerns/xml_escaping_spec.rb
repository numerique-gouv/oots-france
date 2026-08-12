require 'rails_helper'

# Characterisation test, written before the first message was ported: this is
# the behaviour the templates depend on, and the one place where a silent change
# would let a foreign correspondent dictate elements in our own messages.
RSpec.describe XmlEscaping do
  subject(:escaper) { Class.new { include XmlEscaping }.new }

  it 'escapes the ampersand first, so escaping is not applied twice' do
    expect(escaper.escape('Bar & Co')).to eq('Bar &amp; Co')
  end

  it 'escapes an already-escaped entity, because the parser decoded it on the way in' do
    expect(escaper.escape('&amp;')).to eq('&amp;amp;')
  end

  it 'escapes the angle brackets that would otherwise open an element' do
    expect(escaper.escape('<sdg:Name>injecté</sdg:Name>'))
      .to eq('&lt;sdg:Name&gt;injecté&lt;/sdg:Name&gt;')
  end

  it 'escapes the double quote, which would otherwise close an attribute' do
    expect(escaper.escape('il a dit "non"')).to eq('il a dit &quot;non&quot;')
  end

  # It would only need escaping inside an attribute delimited by apostrophes,
  # which the templates never use. Escaping it would clutter every French name
  # for nothing — and changing that would alter the reference messages.
  it 'leaves the apostrophe alone, deliberately' do
    expect(escaper.escape("Ministère de l'enseignement")).to eq("Ministère de l'enseignement")
  end

  it 'renders nil as the empty string, never as the word "nil"' do
    expect(escaper.escape(nil)).to eq('')
  end

  it 'renders false as "false", a value being distinct from an absence' do
    expect(escaper.escape(false)).to eq('false')
  end

  it 'stringifies what is not a string' do
    expect(escaper.escape(42)).to eq('42')
  end

  it 'leaves accented characters untouched, the documents being UTF-8' do
    expect(escaper.escape('Direction interministérielle')).to eq('Direction interministérielle')
  end
end
