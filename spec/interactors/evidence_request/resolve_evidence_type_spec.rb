require 'rails_helper'

RSpec.describe EvidenceRequest::ResolveEvidenceType do
  subject(:resolve) { described_class.call(procedure_code: ProcedureCode::STUDENT_GRANT, common_services:) }

  # The real directory rather than a double: it is a stub for the Evidence
  # Broker, it takes its data as an argument, and what this step does with a
  # procedure the directory does not declare is precisely what is under test.
  let(:common_services) { Directories::CommonServices.new(directory) }

  let(:directory) do
    {
      'typesJustificatif' => [
        { 'id' => 'https://sr.oots.tech.ec.europa.eu/premier', 'formatDistribution' => EvidenceType::PDF },
        { 'id' => 'https://sr.oots.tech.ec.europa.eu/second', 'formatDistribution' => EvidenceType::PDF },
      ],
      'demarches' => [
        {
          'code' => ProcedureCode::STUDENT_GRANT,
          'idsTypeJustificatif' => %w[
            https://sr.oots.tech.ec.europa.eu/premier
            https://sr.oots.tech.ec.europa.eu/second
          ],
        },
      ],
    }
  end

  # Letting the user choose among several is chapter 4.10, and stub 1 of
  # `docs/reste_à_faire.md`: until then the first one is asked for, and which
  # one that is has to be the directory's order rather than an accident.
  it 'keeps the first type the procedure calls for' do
    expect(resolve.evidence_type.id).to eq('https://sr.oots.tech.ec.europa.eu/premier')
  end

  # A procedure declared with no evidence type at all. Reported as a failure of
  # its own rather than left to surface as a nil three steps later, when the
  # message is built.
  describe 'a procedure that calls for nothing' do
    let(:directory) { super().merge('demarches' => [{ 'code' => ProcedureCode::STUDENT_GRANT }]) }

    it 'fails, naming the procedure' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :no_evidence_type, errors: [ProcedureCode::STUDENT_GRANT])
    end
  end

  describe 'a procedure the directory does not declare' do
    let(:directory) { super().merge('demarches' => []) }

    it 'fails, rather than raising at the caller' do
      expect(resolve).to be_failure
      expect(resolve.error).to include(key: :unknown_procedure)
      expect(resolve.error[:errors].first).to include(ProcedureCode::STUDENT_GRANT)
    end
  end
end
