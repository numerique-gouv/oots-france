require 'rails_helper'

RSpec.describe Described do
  let(:described) do
    Struct.new(:descriptions) { include Described }.new({ 'DE' => 'Nachweis', 'EN' => 'Proof', 'FR' => 'Preuve' })
  end

  # RG13: the language the page is read in first, then the other of the two.
  it 'names in the language of the page first' do
    expect([described.label, described.label_language]).to eq(%w[Preuve FR])
    expect(I18n.with_locale(:en) { [described.label, described.label_language] }).to eq(%w[Proof EN])
  end

  it 'falls back on the first published when neither language is' do
    only_german = Struct.new(:descriptions) { include Described }.new({ 'DE' => 'Nachweis' })

    expect([only_german.label, only_german.label_language]).to eq(%w[Nachweis DE])
  end
end
