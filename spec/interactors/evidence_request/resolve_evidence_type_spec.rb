require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveEvidenceType do
  subject(:resolve) do
    described_class.call(procedure_code: ProcedureCode::STUDENT_GRANT, country_code: 'FI', common_services:)
  end

  let(:common_services) { instance_double(Directories::CommonServices, evidence_types_for_procedure: types) }
  let(:types) { [build(:evidence_type, id: 'https://sr/premier'), build(:evidence_type, id: 'https://sr/second')] }

  # Letting the user choose among several is chapter 4.10: until then the first
  # is asked for, and which one that is has to be the directory's order rather
  # than an accident.
  it 'keeps the first type the procedure calls for' do
    expect(resolve.evidence_type.id).to eq('https://sr/premier')
  end

  it 'asks for the types of the country being queried' do
    resolve

    expect(common_services).to have_received(:evidence_types_for_procedure)
      .with(ProcedureCode::STUDENT_GRANT, 'FI')
  end

  # Reported as a failure of its own rather than left to surface as a nil three
  # steps later, when the message is built.
  describe 'a procedure that calls for nothing' do
    let(:types) { [] }

    it 'fails, naming the procedure' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_evidence_type, errors: [ProcedureCode::STUDENT_GRANT])
    end
  end

  describe 'a procedure the broker does not declare' do
    it 'fails, rather than raising at the caller' do
      allow(common_services).to receive(:evidence_types_for_procedure)
        .and_raise(ProcedureCodeNotFound, "Code de démarche « #{ProcedureCode::STUDENT_GRANT} » introuvable.")

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_procedure)
      expect(resolve.error[:errors].first).to include(ProcedureCode::STUDENT_GRANT)
    end
  end

  # A directory that is down is not the caller's fault: the controller answers
  # 502 on this key, where every other failure of this step is a 422.
  describe 'a directory that cannot be reached' do
    it 'fails as an upstream refusal' do
      allow(common_services).to receive(:evidence_types_for_procedure)
        .and_raise(CommonServicesError, 'Annuaire injoignable.')

      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :common_services_refused)
    end
  end
end
