require 'rails_helper'

# The two questions this module answers are not one, and confusing them is what
# separates a conformant request from a malformed one: a correspondent naming a
# published code France does not serve writes a conformant request and gets an
# `EDM:ERR:0004`, where one naming a code the specification does not publish at
# all breaks `R-EDM-REQ-C003`, a FATAL rule, and gets an `EDM:ERR:0003`.
RSpec.describe ProcedureCode do
  describe 'what the specification publishes' do
    it 'holds the codes of the published list' do
      expect(described_class::PUBLISHED).to include('T1', 'R1', 'T3')
    end

    # `R-EDM-REQ-C003` admits it beside the list rather than in it — « For
    # testing purposes the code '00' can be used ».
    it 'leaves the system check beside the list, where the rule puts it' do
      expect(described_class::PUBLISHED).not_to include(described_class::SYSTEM_CHECK)
    end
  end

  # Stub, tracked as OOTS-82: France holds no real evidence, and the three codes
  # below are a demonstration no chapter asks for.
  describe 'what this deployment answers with something' do
    it 'serves the system check and the financing of studies' do
      expect([described_class::SYSTEM_CHECK, described_class::STUDY_FINANCING].map do |code|
        described_class.served?(code)
      end).to eq([true, true])
    end

    # The announcement of chapter 4.5.2 has to be produced somewhere.
    it 'defers the registration of a birth instead of serving it' do
      expect(described_class).to be_deferred(described_class::BIRTH_REGISTRATION)
      expect(described_class).not_to be_served(described_class::BIRTH_REGISTRATION)
    end

    it 'answers all three, each in its own way' do
      answered = [described_class::SYSTEM_CHECK, described_class::STUDY_FINANCING,
                  described_class::BIRTH_REGISTRATION]

      expect(answered.map { |code| described_class.answered?(code) }).to eq([true, true, true])
    end

    # A conformant request all the same: the refusal is `EDM:ERR:0004` and not
    # `EDM:ERR:0003`.
    it 'answers none of the published codes it does not serve' do
      expect(described_class).not_to be_answered(described_class::DIPLOMA_RECOGNITION)
    end

    it 'answers nothing of a code that is no procedure code' do
      expect(described_class).not_to be_answered('ZZ')
    end
  end
end
