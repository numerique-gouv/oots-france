require 'rails_helper'

RSpec.describe Directories::CommonServices do
  subject(:directory) { described_class.new(data) }

  let(:type_id) { 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000' }

  let(:data) do
    {
      'typesJustificatif' => [
        {
          'id' => type_id,
          'descriptions' => { 'FR' => 'Justificatif de test', 'EN' => 'Test evidence' },
          'formatDistribution' => 'application/pdf',
          'fournisseurs' => {
            'FR' => [
              {
                'pointAcces' => { 'id' => 'blue_gw', 'typeId' => 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots' },
                'descriptions' => { 'FR' => 'Fournisseur de test' },
              },
            ],
          },
        },
      ],
      'demarches' => [
        { 'code' => '00', 'idsTypeJustificatif' => [type_id] },
        { 'code' => 'T3', 'idsTypeJustificatif' => [type_id] },
      ],
    }
  end

  describe '#evidence_types_for_procedure' do
    it 'resolves a declared procedure to its evidence types' do
      expect(directory.evidence_types_for_procedure('00').map(&:id)).to eq([type_id])
    end

    it 'raises on a procedure the directory does not declare' do
      expect { directory.evidence_types_for_procedure('T9') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end
  end

  describe '#evidence_type' do
    it 'carries the descriptions and the distribution format' do
      type = directory.evidence_type(type_id)

      expect(type).to have_attributes(distribution_format: 'application/pdf', descriptions: { 'FR' => 'Justificatif de test', 'EN' => 'Test evidence' })
    end

    it 'raises on an unknown identifier' do
      expect { directory.evidence_type('inconnu') }.to raise_error(EvidenceTypeNotFound, /inconnu/)
    end
  end

  describe '#providers' do
    it 'resolves a type and a country to the providers holding it' do
      expect(directory.providers(type_id, 'FR').map(&:access_point_id)).to eq(['blue_gw'])
    end

    it 'raises on a country with no declared provider' do
      expect { directory.providers(type_id, 'DE') }.to raise_error(CountryCodeNotFound, /DE/)
    end

    it 'raises on an unknown evidence type, rather than returning nothing' do
      expect { directory.providers('inconnu', 'FR') }.to raise_error(CountryCodeNotFound)
    end

    # A directory entry missing its access point scheme would otherwise produce
    # a message Domibus accepts and routes nowhere. Failing here names the
    # entry at fault.
    it 'refuses an entry whose access point has no scheme, naming the entry' do
      data['typesJustificatif'][0]['fournisseurs']['FR'][0]['pointAcces'].delete('typeId')

      expect { directory.providers(type_id, 'FR') }
        .to raise_error(ConfigurationError, /pour le pays « FR »/)
    end
  end
end
