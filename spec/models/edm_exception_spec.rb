require 'rails_helper'

RSpec.describe EdmException do
  # Transcribed from the code list published with the TDD 2.0.1:
  # https://code.europa.eu/oots/tdd/tdd_chapters/-/blob/2.0.1/OOTS-EDM/codelists/OOTS/EDMErrorCodes-CodeList.gc
  #
  # Asserted as a whole rather than one example per code: what matters is that
  # the eight are there, in the right order, with the right types — a table
  # copied by hand is exactly the kind of thing that loses a row.
  it 'carries the eight codes of the TDD, each with its exception type' do
    expect(described_class::ALL.map { |e| [e.code, e.type] }).to eq(
      [
        ['EDM:ERR:0001', 'rs:AuthenticationExceptionType'],
        ['EDM:ERR:0002', 'rs:AuthorizationExceptionType'],
        ['EDM:ERR:0003', 'rs:InvalidRequestExceptionType'],
        ['EDM:ERR:0004', 'rs:ObjectNotFoundExceptionType'],
        ['EDM:ERR:0005', 'rs:TimeoutExceptionType'],
        ['EDM:ERR:0006', 'rs:UnresolvedReferenceExceptionType'],
        ['EDM:ERR:0007', 'rs:UnsupportedCapabilityExceptionType'],
        ['EDM:ERR:0008', 'query:QueryExceptionType'],
      ]
    )
  end

  # R-EDM-ERR-C022 ties this severity to the presence of a `PreviewLocation`
  # slot: an authorisation error the user can clear by visiting the provider's
  # preview space is not a failure of the same kind as the seven others.
  it 'gives the preview-required severity to the authorisation error alone' do
    expect(described_class::ALL.select(&:preview_required?)).to eq([described_class::AUTHORIZATION])
  end

  it 'gives every other exception the plain error severity' do
    others = described_class::ALL - [described_class::AUTHORIZATION]

    expect(others.map(&:severity).uniq).to eq([described_class::ERROR])
  end

  it 'freezes the constants, so a caller cannot alter the shared table' do
    expect(described_class::ALL).to all(be_frozen)
  end

  # Chapter 4.5.3 gives `rs:Exception` an optional `detail` for the technical
  # particulars of one failure, where `message` is fixed by the code list and
  # says the same thing every time.
  describe 'the detail one occurrence carries' do
    subject(:detailed) { described_class::INVALID_REQUEST.with_detail('R-EDM-REQ-S016') }

    it 'carries none by default' do
      expect(described_class::INVALID_REQUEST.detail).to be_nil
    end

    it 'answers with a copy carrying it' do
      expect(detailed.detail).to eq('R-EDM-REQ-S016')
    end

    it 'leaves the shared constant untouched' do
      detailed

      expect(described_class::INVALID_REQUEST.detail).to be_nil
    end

    it 'keeps the code and the message the code list fixes' do
      expect(detailed).to have_attributes(code: 'EDM:ERR:0003', type: 'rs:InvalidRequestExceptionType',
        message: described_class::INVALID_REQUEST.message)
    end

    it 'freezes the copy too, so it is no more alterable than the original' do
      expect(detailed).to be_frozen
    end

    # A refusal that has nothing to add — an unreadable slot rather than a named
    # rule — must not turn into a second object saying as much as the first.
    it 'answers with the constant itself when there is nothing to say' do
      expect(described_class::INVALID_REQUEST.with_detail(nil)).to be(described_class::INVALID_REQUEST)
    end
  end
end
