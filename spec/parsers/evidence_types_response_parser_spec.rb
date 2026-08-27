require 'rails_helper'

RSpec.describe EvidenceTypesResponseParser do
  subject(:evidence_types) { described_class.new(body).evidence_types }

  let(:body) { common_services_answer('eb_evidence_types_fr').first }

  # The answer is already restricted to the jurisdiction asked for: the French
  # query returns the French list and not those of the other member states
  # pointing at the same shared requirement.
  it 'reads the evidence types of the jurisdiction queried' do
    expect(evidence_types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])
  end

  it 'keeps the titles the directory publishes' do
    expect(evidence_types.first.descriptions).to include('EN' => 'FR - Test Evidence Type')
  end

  # An unstructured evidence type declares no format, and the model's default
  # is what the rest of the chain expects.
  it 'leaves the distribution format to its default when none is declared' do
    expect(evidence_types.first.distribution_format).to eq(EvidenceType::PDF)
  end

  # The Finnish answer to the same requirement, and the type the DSD fixture
  # answers for: reading it here is what ties the two halves of the chain to
  # the same real exchange.
  it 'reads the Finnish type the data service directory then resolves' do
    finnish = described_class.new(common_services_answer('eb_evidence_types_fi').first)

    expect(finnish.evidence_types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74'])
  end

  it 'refuses a requirement carrying no evidence type' do
    stripped = body.gsub(%r{<sdg:EvidenceTypeList>.*</sdg:EvidenceTypeList>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # Left unvalidated, the type would travel as far as the
  # `EvidenceTypeClassification` slot of an outgoing request and go out empty.
  it 'refuses an entry the directory published without a classification' do
    stripped = body.sub(%r{<sdg:EvidenceTypeClassification>.*?</sdg:EvidenceTypeClassification>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /annoncé par l'annuaire/)
  end

  # Several lists are alternatives to one another, and several types within a
  # list are needed together; the answer for France carries one of each, so the
  # flattening is exercised on a hand-built body.
  it 'flattens the types of every list the requirement carries' do
    expect(described_class.new(two_lists).evidence_types.map(&:id)).to eq(%w[https://sr/premier https://sr/second])
  end

  # Within a list every type is needed; two lists answering one requirement are
  # alternatives. Flattening loses that, which is why the grouping is kept
  # beside it.
  it 'keeps the lists the directory groups the types into' do
    lists = described_class.new(two_lists).evidence_type_lists

    expect(lists.size).to eq(2)
    expect(lists.map { |list| list.evidence_types.map(&:id) })
      .to eq([['https://sr/premier'], ['https://sr/second']])
  end

  # `country-code` being optional on this query, one answer carries the lists
  # of every member state, and each names the jurisdiction it belongs to.
  it 'reads the jurisdiction each list belongs to' do
    expect(described_class.new(body).evidence_type_lists.map(&:country)).to eq(['FR'])
  end

  # Chapter 3.2.4: a member state that knows it issues nothing declares an empty
  # list carrying `NoMatch`, in an answer that succeeds. Reading that as « we
  # could not read this » reports a directory that answered as one that refused.
  describe 'a jurisdiction declaring it holds nothing' do
    subject(:declared) { described_class.new(evidence_types_declaring_no_match(reason:)) }

    let(:reason) { 'No MS-issued evidence available for SMEs in Dutch Speaking Community' }

    it 'reads the answer rather than rejecting it as unreadable' do
      expect(declared.evidence_types).to be_empty
      expect(declared.evidence_type_lists.map(&:no_match?)).to eq([true])
    end

    it 'keeps the explanation the directory published, in the language it named' do
      expect(declared.evidence_type_lists.first.match_descriptions).to eq('EN' => reason)
    end

    # The explanation is optional (`sdg:MatchDescription`, 0..n): a member state
    # may declare a `NoMatch` and say nothing more.
    it 'reads a declaration carrying no explanation' do
      silent = described_class.new(evidence_types_declaring_no_match)

      expect(silent.evidence_type_lists.first).to be_no_match
      expect(silent.evidence_type_lists.first.match_description).to be_nil
    end
  end

  # `R-EB-EVI-S015` excuses a list without evidence types only under `NoMatch`:
  # anything else empty is an answer we failed to read.
  it 'refuses an empty list the directory did not declare as a NoMatch' do
    emptied = body.sub(%r{<sdg:EvidenceType>.*?</sdg:EvidenceType>}m, '')

    expect { described_class.new(emptied) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # TDD 2.0 uses `NoMatch` alone and reserves the other degrees of match for
  # later releases (`R-EB-EVI-C043`). One of those, arriving early, is read and
  # kept — but it does not excuse an empty list.
  it 'refuses an empty list carrying a match type this release does not know' do
    other = evidence_types_declaring_no_match.sub('>NoMatch<', '>BestMatch<')

    expect { described_class.new(other) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # `country-code` is optional on this query, so one answer carries the lists of
  # several member states at once — the path the console takes. A declaration
  # from one of them says nothing about a neighbour's silence: `R-EB-EVI-S015`
  # bears on one list, so every empty list has to declare itself.
  it 'refuses an answer where one list declares itself and another stays silent' do
    mixed = with_first_list(evidence_types_declaring_no_match) do |declared|
      declared + declared.sub(%r{<sdg:MatchType>.*?</sdg:MatchType>}m, '')
    end

    expect { described_class.new(mixed) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # The chapter forbids a `NoMatch` overlapping a jurisdiction that provides
  # another match type, not a requirement carrying both — and the answer is
  # read, the declaration kept beside the types.
  it 'reads a declaration standing beside a list that carries types' do
    beside = evidence_types_declaring_no_match_beside_types

    read = described_class.new(beside)

    expect(read.evidence_type_lists.map(&:no_match?)).to eq([false, true])
    expect(read.evidence_types.size).to eq(1)
  end

  # The two cases the chapter separates, side by side: one list says nothing
  # exists, the other says nothing is known.
  it 'leaves a refusal by EB:ERR:0001 a refusal' do
    expect { described_class.new(common_services_answer('eb_requirements_vides').first) }
      .to raise_error(CommonServicesError) { |raised| expect(raised.code).to eq('EB:ERR:0001') }
  end

  def two_lists
    with_first_list do |one|
      [one.sub(%r{(<sdg:EvidenceTypeClassification>).*?(</sdg:EvidenceTypeClassification>)}m, '\1https://sr/premier\2'),
       one.sub(%r{(<sdg:EvidenceTypeClassification>).*?(</sdg:EvidenceTypeClassification>)}m, '\1https://sr/second\2')]
        .join
    end
  end

  # The captured answer carries one combination; every case below is that one,
  # rewritten or set beside a variant of itself.
  def with_first_list(source = body, &)
    source.sub(%r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m) { yield(Regexp.last_match(1)) }
  end
end
