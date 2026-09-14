require 'rails_helper'

# Read back through `pdf-reader` and never as bytes: the font is embedded as a
# subset, so nothing the document says can be found by searching the file for a
# string.
RSpec.describe EvidenceDocumentBuilder do
  subject(:text) { text_of(described_class.new(**attributes).render) }

  # 15:03:27 in Paris, which is what the document must print of it.
  let(:instant) { Time.utc(2026, 9, 14, 13, 3, 27) }

  let(:evidence_type) do
    EvidenceType.new(
      id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
      descriptions: { 'EN' => 'Certificate of Birth', 'FR' => 'Acte de naissance' },
      distribution_formats: ['application/pdf'],
    )
  end

  # A subject carrying everything a request may describe them by, so that what
  # the document leaves out is left out of something that carried it.
  let(:beneficiary) do
    NaturalPerson.new(
      eidas_identifier: 'FR/DE/123123123', level_of_assurance: 'High',
      family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
      place_of_birth: 'Lyon', gender: 'Male',
    )
  end

  let(:attributes) do
    { evidence_id: '3f2a1b0c-0000-4000-8000-00000000000a', instant:, evidence_type:, beneficiary: }
  end

  describe 'the bytes it produces' do
    it 'are the same for the same inputs' do
      produced = Array.new(2) { described_class.new(**attributes).render }

      expect(produced.uniq.size).to eq(1)
    end

    # RG6: two answers never produce the same document, the evidence identifier
    # being drawn afresh for each.
    it 'differ as soon as the evidence identifier does' do
      other = described_class.new(**attributes, evidence_id: '3f2a1b0c-0000-4000-8000-00000000000b')

      expect(other.render).not_to eq(described_class.new(**attributes).render)
    end
  end

  # CA3: the instant of the `IssueDateTime` slot, said in Paris time as a reader
  # of a French document expects it.
  it 'prints the date and the time it was produced at, in Paris time' do
    expect(text).to include('14/09/2026').and include('15:03:27')
  end

  # CA4: chapter 4.5.1 §3.5 lets a request name a title per language, and the
  # document prints every one of them rather than choosing.
  it 'prints every title the request gave the evidence type, in its own language' do
    expect(text).to include('Certificate of Birth').and include('Acte de naissance')
    expect(text).to include('EN').and include('FR')
  end

  it 'prints the classification identifier of the evidence type' do
    expect(unbroken(text)).to include(evidence_type.id)
  end

  # CA5: of the seven attributes a response may carry about a natural person,
  # the document prints the three the journal builds its canonical key from.
  it 'prints of a natural person their name, their given name and their date of birth' do
    expect(text).to include('Dupont').and include('Jean').and include('1992-10-22')
  end

  it 'prints nothing else the request said of them' do
    expect(text).not_to include('FR/DE/123123123')
    expect(text).not_to include('High')
    expect(text).not_to include('Lyon')
    expect(text).not_to include('Male')
  end

  # CA6: the eIDAS identifier of an organisation is the pseudonym its canonical
  # key is made of, and a demonstration document has no business carrying it.
  describe 'when the subject is an organisation' do
    let(:beneficiary) do
      LegalPerson.new(eidas_identifier: 'FR/DE/A2635542Y', legal_name: 'Établissements Dupont & Fils')
    end

    it 'prints its legal name and not its eIDAS identifier' do
      expect(text).to include('Établissements Dupont & Fils')
      expect(text).not_to include('FR/DE/A2635542Y')
    end
  end

  # CA14: the wording is French; only the titles of the evidence type stay in the
  # language the request wrote them in.
  it 'says in French what it is and what it shows' do
    expect(text).to include('Justificatif de démonstration')
    expect(text).to include('Type de justificatif demandé').and include('Usager concerné')
  end

  it 'prints the identifier the response gives the evidence' do
    expect(text).to include(attributes.fetch(:evidence_id))
  end

  # CA15: the flag itself is judged by eye, in the walk-through of the
  # Verification; what a spec can hold is that an image is embedded at all.
  it 'embeds an image' do
    document = PDF::Reader.new(StringIO.new(described_class.new(**attributes).render))

    expect(document.pages.first.xobjects.values.map { |object| object.hash[:Subtype] }).to include(:Image)
  end

  # Why the font is a TrueType one versioned here rather than one of prawn's
  # built-in AFM fonts: those encode Windows-1252 and raise on anything outside
  # it, so this very request would fail the construction of the whole response.
  describe 'a title written in an alphabet Windows-1252 does not cover' do
    let(:evidence_type) do
      EvidenceType.new(
        id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/EL/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        descriptions: { 'EL' => 'Πιστοποιητικό γέννησης', 'PL' => 'Akt urodzenia' },
        distribution_formats: ['application/pdf'],
      )
    end

    it 'is printed as it was received' do
      expect(text).to include('Πιστοποιητικό γέννησης').and include('Akt urodzenia')
    end
  end

  # As `EvidenceSubjectBuilder` does it: a subject of a type nobody listed fails
  # the construction rather than producing a document silent about whom it is
  # about.
  it 'refuses a subject of a type it does not know how to describe' do
    expect { described_class.new(**attributes, beneficiary: 'Dupont').render }
      .to raise_error(ConfigurationError, /String/)
  end

  # The one family of keys this builder composes at run time, and which
  # `i18n-tasks` therefore exempts: what it prints of a subject depends on the
  # kind of subject it was given.
  it 'has a wording for every field it prints of a subject' do
    expect_said(described_class::SUBJECT_FIELDS.values.flatten.uniq
      .map { |field| "builders.evidence_document_builder.fields.#{field}" })
  end

  def text_of(document) = PDF::Reader.new(StringIO.new(document)).pages.map(&:text).join("\n")

  # A value prawn laid over two lines arrives with the break inside it, which is
  # how a hundred-character classification URL comes back.
  def unbroken(rendered) = rendered.gsub(/\s+/, '')
end
