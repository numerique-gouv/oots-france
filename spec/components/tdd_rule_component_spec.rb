require 'rails_helper'

RSpec.describe TddRuleComponent, type: :component do
  # The `.sch` and not the chapter, which carries the rule too: this address is
  # pinned to a version tag where the wiki page is live.
  it 'links a content rule to the Schematron file asserting it' do
    render_inline(described_class.new(rule: 'R-DSD-RESP-C041'))

    expect(page).to have_link('R-DSD-RESP-C041',
      href: 'https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/DSD-RESP-C.sch')
  end

  # The letter of the identifier picks the file: the structural assertions are
  # published apart from the content ones, under the same name.
  it 'links a structural rule to the other file of the same set' do
    render_inline(described_class.new(rule: 'R-DSD-RESP-S027'))

    expect(page).to have_link('R-DSD-RESP-S027',
      href: 'https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/DSD-RESP-S.sch')
  end

  # The sets published without a `-C`/`-S` split number their rules without the
  # letter, and their file is named accordingly: the separator is what the
  # derivation has to drop, not a fixed number of characters.
  it 'links a rule of an unsplit set to the file of that set' do
    render_inline(described_class.new(rule: 'R-EB-ERR-005'))

    expect(page).to have_link('R-EB-ERR-005',
      href: 'https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/EB-ERR.sch')
  end

  # `MS-CLASS-SUB` numbers its rules with a letter without being split in two:
  # the letter belongs to the number there, and keeping it would address a file
  # the tree does not carry.
  it 'links a rule whose letter belongs to its number to the set itself' do
    render_inline(described_class.new(rule: 'R-MS-CLASS-SUB-S001'))

    expect(page).to have_link('R-MS-CLASS-SUB-S001',
      href: 'https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/sch/MS-CLASS-SUB.sch')
  end

  it 'opens the rule in a new window, and says so' do
    render_inline(described_class.new(rule: 'R-DSD-RESP-C039'))

    expect(page).to have_css("a[target='_blank'][rel='noopener']")
    expect(page).to have_css("a[title*='nouvelle fenêtre']")
  end
end
