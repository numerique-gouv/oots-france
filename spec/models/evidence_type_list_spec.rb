require 'rails_helper'

RSpec.describe EvidenceTypeList do
  describe '.distinct_evidence_types' do
    it 'counts a type once however many alternatives call on it' do
      shared = build(:evidence_type, id: 'https://sr/evidencetypeclassifications/FR/shared')
      lists = [build(:evidence_type_list, evidence_types: [shared]),
               build(:evidence_type_list, id: 'other', evidence_types: [shared])]

      expect(described_class.distinct_evidence_types(lists).map(&:id))
        .to eq(['https://sr/evidencetypeclassifications/FR/shared'])
    end

    # The reason `uniq(&:id)` and not `uniq`: `EvidenceType` includes
    # `ActiveModel::Model` without value equality, so a bare `uniq` compares
    # object identity and two readings of one classification never match.
    it 'deduplicates on the classification and not on object identity' do
      lists = [build(:evidence_type_list,
        evidence_types: [build(:evidence_type, id: 'https://sr/x'),
                         build(:evidence_type, id: 'https://sr/x')])]

      expect(described_class.distinct_evidence_types(lists).size).to eq(1)
      expect(lists.flat_map(&:evidence_types).uniq.size).to eq(2)
    end

    it 'keeps the types the alternatives do not share' do
      lists = [build(:evidence_type_list, evidence_types: [build(:evidence_type, id: 'https://sr/a')]),
               build(:evidence_type_list, id: 'other', evidence_types: [build(:evidence_type, id: 'https://sr/b')])]

      expect(described_class.distinct_evidence_types(lists).map(&:id)).to eq(['https://sr/a', 'https://sr/b'])
    end

    # A jurisdiction declaring it issues nothing carries no type, and must not
    # make the count fail.
    it 'counts nothing for a declaration of non-delivery' do
      expect(described_class.distinct_evidence_types([build(:evidence_type_list, :no_match)])).to be_empty
      expect(described_class.distinct_evidence_types([])).to be_empty
    end
  end

  describe '#no_match?' do
    it 'recognises the declaration a member state makes to say it issues nothing' do
      expect(build(:evidence_type_list, :no_match)).to be_no_match
    end

    # Emptied on purpose: with the types the factory gives, the predicate would
    # answer `false` whatever the match type says, and this example would pass
    # even with the clause it exists to pin down deleted.
    it 'is false where the directory declared no match type at all' do
      expect(build(:evidence_type_list, :no_match, match_type: nil)).not_to be_no_match
    end

    # TDD 2.0 reserves the other degrees of match for later releases
    # (`R-EB-EVI-C043`), and one arriving early says nothing about emptiness:
    # `R-EB-EVI-S015` excuses a list without evidence types only under
    # `NoMatch`.
    it 'is false for a match type this release does not know' do
      expect(build(:evidence_type_list, :no_match, match_type: 'BestMatch')).not_to be_no_match
    end

    # « In this case, EvidenceTypeList must be empty » : a declaration the types
    # beside it contradict is not one, and those types are what the page shows.
    it 'is false where the declaration is contradicted by the types beside it' do
      contradicted = build(:evidence_type_list, :no_match, evidence_types: [build(:evidence_type)])

      expect(contradicted).not_to be_no_match
    end
  end

  describe '#published?' do
    it 'is true where the jurisdiction carries a type' do
      expect(build(:evidence_type_list)).to be_published
    end

    it 'is false for a declaration of non-delivery' do
      expect(build(:evidence_type_list, :no_match)).not_to be_published
    end

    # The two predicates are not each other's negation, and a filter written as
    # one when it meant the other would count this list among what a country
    # publishes.
    it 'is false for a list left empty without declaring itself' do
      silent = build(:evidence_type_list, evidence_types: [], match_type: nil)

      expect(silent).not_to be_published
      expect(silent).not_to be_no_match
    end
  end

  describe '#match_description' do
    it 'reads the explanation in the same preferred language as every other wording' do
      declared = build(:evidence_type_list, :no_match,
        match_descriptions: { 'EN' => 'No evidence issued', 'FR' => 'Aucun justificatif délivré' })

      expect(declared.match_description).to eq('Aucun justificatif délivré')
    end

    # `sdg:MatchDescription` is optional: a member state may declare a `NoMatch`
    # and say nothing more.
    it 'is nil where the directory published no explanation' do
      expect(build(:evidence_type_list, :no_match, match_descriptions: {}).match_description).to be_nil
    end
  end

  # A page rendering the explanation has to declare the language it is written
  # in, which is rarely French: the chapter has member states write it in a
  # widely understood one (RGAA 8.7).
  describe '#match_description_language' do
    it 'names the language of the explanation it chose' do
      declared = build(:evidence_type_list, :no_match,
        match_descriptions: { 'EN' => 'No evidence issued', 'FR' => 'Aucun justificatif délivré' })

      expect(declared.match_description_language).to eq('FR')
    end

    # Neither preferred language published: the first the directory wrote is
    # taken, which is its own order and not chance — and it is that one whose
    # language the page must declare.
    it 'names the language actually shown when neither preferred one is published' do
      declared = build(:evidence_type_list, :no_match, match_descriptions: { 'DE' => 'Keine Nachweise' })

      expect(declared.match_description_language).to eq('DE')
      expect(declared.match_description).to eq('Keine Nachweise')
    end

    it 'is nil where the directory published no explanation' do
      expect(build(:evidence_type_list, :no_match, match_descriptions: {}).match_description_language).to be_nil
    end
  end
end
