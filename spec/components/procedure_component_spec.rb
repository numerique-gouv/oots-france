require 'rails_helper'

RSpec.describe ProcedureComponent, type: :component do
  # The key is borne by a constant, so no scanner sees it written as a lookup
  # — neither `i18n-tasks` nor anything reading the source.
  it 'says the label it falls back on' do
    expect(I18n.t(described_class::NO_LABEL, raise: true)).to be_present
  end

  # The test procedure « 00 » appears in no code list, and a member state now
  # and then declares one the list ignores.
  it 'stands in for a procedure the code list does not name' do
    render_inline(described_class.new(code: '00'))

    expect(page).to have_text('00')
    expect(page).to have_text(I18n.t(described_class::NO_LABEL))
  end
end
