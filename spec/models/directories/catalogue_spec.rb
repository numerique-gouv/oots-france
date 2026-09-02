require 'rails_helper'

RSpec.describe Directories::Catalogue do
  subject(:catalogue) { described_class.new(evidence_broker:) }

  let(:evidence_broker) { instance_double(EvidenceBrokerClient, requirements: published) }

  let(:published) do
    [
      build(:requirement, id: 'https://sr/exigences/aaa', reference_frameworks: [
        build(:reference_framework, procedure_code: 'X10', country: 'DE'),
        build(:reference_framework, procedure_code: 'R1', country: 'BE'),
      ]),
      build(:requirement, id: 'https://sr/exigences/bbb', reference_frameworks: [
        build(:reference_framework, procedure_code: 'X2', country: 'FR'),
        build(:reference_framework, procedure_code: 'R1', country: 'FR'),
      ]),
    ]
  end

  # A declaration the directory published without its jurisdiction names no
  # country, and counting it would announce one member state more than there
  # are — on the very page an operator opens to see how many there are.
  it 'leaves out a declaration whose jurisdiction the directory published empty' do
    published << build(:requirement, id: 'https://sr/exigences/ccc', reference_frameworks: [
      build(:reference_framework, procedure_code: 'R1', country: ''),
    ])

    expect(catalogue.countries).to eq(%w[BE DE FR])
  end

  # The directory publishes no procedure as such: it holds the declarations
  # member states make, each naming the code it maps onto.
  it 'builds a procedure out of the declarations naming the same code' do
    expect(catalogue.procedure('R1').countries).to eq(%w[BE FR])
    expect(catalogue.procedure('R1').requirements.map(&:id)).to eq(%w[https://sr/exigences/aaa https://sr/exigences/bbb])
  end

  # Sorted on the letters and the number apart: plain string order would file
  # `X10` between `X1` and `X2`.
  it 'orders the procedures as a reader expects to find them' do
    expect(catalogue.procedures.map(&:code)).to eq(%w[R1 X2 X10])
  end

  it 'answers nothing for a code no member state has declared' do
    expect(catalogue.procedure('T3')).to be_nil
  end

  it 'finds a requirement by the short name the console addresses it with' do
    expect(catalogue.requirement('bbb').id).to eq('https://sr/exigences/bbb')
  end

  it 'lists the countries appearing anywhere in the catalogue' do
    expect(catalogue.countries).to eq(%w[BE DE FR])
  end

  # A declaration with no code belongs to no procedure, and a heading with no
  # name is worse than a line missing from a listing.
  it 'leaves out a declaration published without a procedure code' do
    published << build(:requirement, id: 'https://sr/exigences/ccc', reference_frameworks: [
      build(:reference_framework, procedure_code: nil, country: 'IT'),
    ])

    expect(catalogue.procedures.map(&:code)).to eq(%w[R1 X2 X10])
  end

  describe '#published_in' do
    # The page reached from this method announces « les exigences pour
    # lesquelles il publie un type de justificatif », and counts them in its own
    # tally. A `NoMatch` says the country issues nothing (chapter 3.2.4), so
    # counting it there would announce the opposite of what the country
    # declared — and the tally is read without opening a single card.
    it 'leaves out an explicit declaration that the country issues nothing' do
      allow(evidence_broker).to receive(:evidence_type_lists)
        .and_return([build(:evidence_type_list, :no_match, country: 'FR')])

      expect(catalogue.published_in('FR')).to be_empty
    end

    it 'keeps a requirement the country does publish a type for' do
      allow(evidence_broker).to receive(:evidence_type_lists)
        .and_return([build(:evidence_type_list, country: 'FR')])

      expect(catalogue.published_in('FR').map { |requirement, _| requirement.id })
        .to eq(%w[https://sr/exigences/aaa https://sr/exigences/bbb])
    end

    # Neither a declaration nor a publication. `no_match?` is false for it, so a
    # filter written as that predicate's negation would count it among what the
    # country publishes — the very bug this method just shed. It reaches here
    # because the parser judges an answer readable on the whole batch, and a
    # neighbour carrying types is enough.
    it 'leaves out a list left empty without declaring itself' do
      allow(evidence_broker).to receive(:evidence_type_lists)
        .and_return([build(:evidence_type_list, country: 'FR', evidence_types: [])])

      expect(catalogue.published_in('FR')).to be_empty
    end

    # Both belong to the same jurisdiction, which the chapter forbids — a
    # `NoMatch` must not overlap a jurisdiction that provides another match
    # type. Read defensively all the same: what the country publishes stays,
    # the declaration contradicting it goes, and the requirement is still the
    # country's to answer.
    it 'keeps the published list beside a declaration from the same country' do
      allow(evidence_broker).to receive(:evidence_type_lists).and_return([
        build(:evidence_type_list, :no_match, country: 'FR'),
        build(:evidence_type_list, country: 'FR'),
      ])

      _, lists = catalogue.published_in('FR').first

      expect(lists.map(&:no_match?)).to eq([false])
    end
  end

  describe '#publishing_countries' do
    # The listing this feeds announces the countries that satisfy the
    # requirement. A `NoMatch` says the country issues nothing (chapter 3.2.4),
    # so naming it there would state the opposite of what it declared — the
    # same rule `published_in` applies, and for the same reason.
    it 'names the countries publishing a type, and not the one declaring it issues none' do
      allow(evidence_broker).to receive(:evidence_type_lists).and_return([
        build(:evidence_type_list, country: 'IT'),
        build(:evidence_type_list, :no_match, country: 'BE'),
        build(:evidence_type_list, country: 'AT'),
      ])

      expect(catalogue.publishing_countries(published.first)).to eq(%w[AT IT])
    end

    it 'names a country once, however many combinations it publishes' do
      allow(evidence_broker).to receive(:evidence_type_lists).and_return([
        build(:evidence_type_list, country: 'AT'),
        build(:evidence_type_list, country: 'AT'),
      ])

      expect(catalogue.publishing_countries(published.first)).to eq(%w[AT])
    end
  end

  # The branch the whole sweep rests on, and the only one no page can show:
  # a requirement the directory holds nothing about is skipped, and its
  # neighbours are answered all the same.
  it 'folds an empty result set into no publisher, leaving the other requirements answered' do
    allow(evidence_broker).to receive(:evidence_type_lists) do |requirement_id:|
      raise CommonServicesError.new('vide', code: 'EB:ERR:0001') if requirement_id.end_with?('aaa')

      [build(:evidence_type_list, country: 'FR')]
    end

    expect(catalogue.publishing_countries(published.first)).to be_empty
    expect(catalogue.publishing_countries(published.second)).to eq(%w[FR])
    expect(catalogue.published_in('FR').map { |requirement, _| requirement.id }).to eq(%w[https://sr/exigences/bbb])
  end

  # Fifty-three questions are asked, and the page renders the refusal of one of
  # them: without the requirement, it would name none in particular.
  it 'names the requirement the sweep fell on when it relays a refusal' do
    allow(evidence_broker).to receive(:evidence_type_lists)
      .and_raise(CommonServicesError.new("L'annuaire a refusé", code: 'EB:ERR:0002'))

    expect { catalogue.publishing_countries(published.first) }
      .to raise_error(CommonServicesError, /aaa/) { |error| expect(error.code).to eq('EB:ERR:0002') }
  end

  # The two questions are opposite ends of one sweep, and the console asks both
  # of the same catalogue: asking the directory twice would double fifty-three
  # queries for nothing.
  it 'sweeps once for what a country publishes and for who publishes a requirement' do
    allow(evidence_broker).to receive(:evidence_type_lists).and_return([build(:evidence_type_list, country: 'FR')])

    catalogue.published_in('FR')
    catalogue.publishing_countries(published.first)

    expect(evidence_broker).to have_received(:evidence_type_lists).twice
  end

  # `CommonServicesQuery` caches the body rather than what was read from it, so
  # a second ask costs a second parse of some six hundred kilobytes.
  it 'asks the directory once, however many angles the page reads it from' do
    catalogue.procedures
    catalogue.requirements
    catalogue.countries

    expect(evidence_broker).to have_received(:requirements).once
  end
end
