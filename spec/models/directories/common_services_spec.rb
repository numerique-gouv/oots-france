require 'rails_helper'

RSpec.describe Directories::CommonServices do
  subject(:directory) { described_class.new(evidence_broker: broker, data_service_directory: dsd) }

  let(:requirement) { build(:requirement) }
  let(:broker) do
    instance_double(EvidenceBrokerClient, requirements: [requirement], evidence_types: [type])
  end
  let(:dsd) { instance_double(DataServiceDirectoryClient, data_services: [service]) }
  let(:second) { build(:requirement, id: 'https://sr.oots.tech.ec.europa.eu/requirements/11111111-1111-1111-1111-111111111111') }
  let(:type) { build(:evidence_type) }
  let(:other_type) { build(:evidence_type, id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/11111111-1111-1111-1111-111111111111') }
  let(:service) { build(:data_service) }

  describe '#required_evidence_for_procedure' do
    it 'chains the two broker queries, the requirement leading to the types' do
      expect(directory.required_evidence_for_procedure('00', 'FI'))
        .to eq([described_class::RequiredEvidence.new(requirement:, evidence_types: [type])])

      expect(broker).to have_received(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
    end

    # The procedure is ours, so its requirements are read in our jurisdiction;
    # only the types that satisfy them are read in the country being asked.
    it 'reads the requirements in our own jurisdiction, not in the one asked' do
      directory.required_evidence_for_procedure('00', 'FI')

      expect(broker).to have_received(:requirements).with(procedure_code: '00', country_code: 'FR')
    end

    it 'raises on a procedure the broker holds no requirement for' do
      allow(broker).to receive(:requirements).and_return([])

      expect { directory.required_evidence_for_procedure('T9', 'FI') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end

    it 'turns the broker refusal on an unknown procedure into the same error' do
      allow(broker).to receive(:requirements).and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0001'))

      expect { directory.required_evidence_for_procedure('T9', 'FI') }
        .to raise_error(ProcedureCodeNotFound, /T9/)
    end

    it 'turns a refusal on the second query into an unknown evidence type' do
      allow(broker).to receive(:evidence_types).and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0002'))

      expect { directory.required_evidence_for_procedure('00', 'FI') }
        .to raise_error(EvidenceTypeNotFound, /FI/)
    end

    # An outage is not the caller's fault, and translating it into a 422 would
    # blame them for it.
    it 'lets a failure carrying no code through, rather than blaming the caller' do
      allow(broker).to receive(:requirements).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.required_evidence_for_procedure('00', 'FI') }
        .to raise_error(CommonServicesError, /injoignable/)
    end

    # R-EDM-REQ-C008 bounds the shape of that identifier, and a directory is not
    # obliged to honour it — the console lists such an entry, a message cannot
    # carry it.
    it 'refuses a requirement whose identifier no message could carry' do
      allow(broker).to receive(:requirements).and_return([build(:requirement, id: 'https://sr/exigence/1')])

      expect { directory.required_evidence_for_procedure('00', 'FI') }
        .to raise_error(InvalidDirectoryEntry, /L'exigence annoncée/)
    end

    # Chapter 3.2.3: « Each procedure has one or more specific requirements that
    # need to be fulfilled by the User that executes the procedure. » They are
    # conjunctive, so keeping one of them is losing a piece of evidence.
    describe 'a procedure resting on several requirements' do
      before { allow(broker).to receive(:requirements).and_return([requirement, second]) }

      # `requirement-id` is MANDATORY on the second query (chapter 3.2.4), which
      # is what makes n requirements cost n calls.
      it 'resolves each of them, in the order the directory published them' do
        allow(broker).to receive(:evidence_types)
          .with(requirement_id: second.id, country_code: 'FI').and_return([other_type])

        expect(directory.required_evidence_for_procedure('00', 'FI')).to eq([
          described_class::RequiredEvidence.new(requirement:, evidence_types: [type]),
          described_class::RequiredEvidence.new(requirement: second, evidence_types: [other_type]),
        ])

        expect(broker).to have_received(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
      end

      # A member state declaring it issues nothing under this jurisdiction: the
      # entry stays, so a caller counting the requirements of the procedure
      # still sees them all.
      it 'keeps the entry of a requirement the country declares nothing for' do
        allow(broker).to receive(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
          .and_return([])

        expect(directory.required_evidence_for_procedure('00', 'FI')).to eq([
          described_class::RequiredEvidence.new(requirement:, evidence_types: []),
          described_class::RequiredEvidence.new(requirement: second, evidence_types: [type]),
        ])
      end

      # `EB:ERR:0001` answers one query, about one requirement in one country —
      # it is not a verdict on the procedure, and the requirements the broker
      # does answer are due whatever it says about this one.
      it 'holds back a refusal on one requirement while another publishes types' do
        allow(broker).to receive(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
          .and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0001'))

        expect(directory.required_evidence_for_procedure('00', 'FI'))
          .to eq([described_class::RequiredEvidence.new(requirement:, evidence_types: []),
                  described_class::RequiredEvidence.new(requirement: second, evidence_types: [type])])
      end

      # Held back, not swallowed: with nothing to set against it, the refusal is
      # the whole answer, and a caller must be able to tell it from the country
      # declaring it issues nothing.
      #
      # It wins over the `NoMatch` beside it on purpose. Answering « this
      # country has no evidence type for this procedure » would claim to know
      # about the refused requirement, which is the one thing the directory just
      # said it knows nothing about; the refusal claims only that we could not
      # find out, which is true of both.
      it 'raises that refusal when no requirement published anything' do
        allow(broker).to receive(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
          .and_raise(CommonServicesError.new('vide', code: 'EB:ERR:0001'))
        allow(broker).to receive(:evidence_types).with(requirement_id: second.id, country_code: 'FI')
          .and_return([])

        expect { directory.required_evidence_for_procedure('00', 'FI') }
          .to raise_error(EvidenceTypeNotFound, /FI/)
      end

      it 'refuses an identifier no message could carry wherever it sits' do
        refused = build(:requirement, id: 'https://sr/exigence/1')

        [[requirement, refused], [refused, requirement]].each do |published|
          allow(broker).to receive(:requirements).and_return(published)

          expect { directory.required_evidence_for_procedure('00', 'FI') }
            .to raise_error(InvalidDirectoryEntry, /L'exigence annoncée/)
        end
      end

      # `EB:ERR:0002` answers a query that named no requirement — a fault of
      # ours, and never a fact about the country — so the holding back that
      # `EB:ERR:0001` earns must not extend to it, whatever the neighbours say.
      # `Directories::Catalogue#published_in` draws the same line.
      it 'never holds back a refusal that blames our own query' do
        allow(broker).to receive(:evidence_types).with(requirement_id: requirement.id, country_code: 'FI')
          .and_raise(CommonServicesError.new('sans exigence', code: 'EB:ERR:0002'))

        expect { directory.required_evidence_for_procedure('00', 'FI') }
          .to raise_error(EvidenceTypeNotFound, /FI/)
      end

      # A directory that cannot be reached says nothing about the country, so it
      # is not held back either: swallowing it would let an outage read as a
      # country that publishes nothing.
      it 'lets an outage on one requirement stop the whole answer' do
        allow(broker).to receive(:evidence_types).with(requirement_id: second.id, country_code: 'FI')
          .and_raise(CommonServicesError, 'annuaire injoignable')

        expect { directory.required_evidence_for_procedure('00', 'FI') }
          .to raise_error(CommonServicesError, /injoignable/)
      end
    end
  end

  describe '#data_service' do
    # The service and not the provider alone: a request adopts the record, its
    # identifier and its distribution included, and the provider is one of the
    # things that record holds.
    it 'resolves a type and a country to the service delivering it' do
      expect(directory.data_service(type.id, 'FI')).to eq(service)

      expect(dsd).to have_received(:data_services)
        .with(evidence_type_classification: type.id, country_code: 'FI')
    end

    # A record published without `sdg:AccessService` breaks R-DSD-RESP-S014;
    # writing its identifier would pair it with a provider another record
    # announced, and refusing the exchange would ignore a service that works.
    it 'keeps the first service that names a provider, not simply the first' do
      silent = build(:data_service, id: 'a3ff6ed8-1cbf-4a4a-9d20-3fa1c0ef7ac5', providers: [])
      allow(dsd).to receive(:data_services).and_return([silent, service])

      expect(directory.data_service(type.id, 'FI')).to eq(service)
    end

    it 'answers nothing when no service names a provider' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, providers: [])])

      expect(directory.data_service(type.id, 'FI')).to be_nil
    end

    # R-EDM-REQ-C026 makes that identifier a UUID, and R-EDM-REQ-C027 the
    # classification a Semantic Repository URL.
    it 'refuses a service whose identifier no message could carry' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, id: 'service-de-test')])

      expect { directory.data_service(type.id, 'FI') }
        .to raise_error(InvalidDirectoryEntry, /Le service de données annoncé/)
    end

    # R-DSD-RESP-C010 bounds the data model the directory may publish, and the
    # request carries that value back word for word: an entry breaking it would
    # reach a correspondent as a URL pointing at nothing.
    it 'refuses a service whose data model no message could carry' do
      published = build(:data_service, distribution_conforms_to: 'https://sr.oots.tech.ec.europa.eu/distributions/1')
      allow(dsd).to receive(:data_services).and_return([published])

      expect { directory.data_service(type.id, 'FI') }
        .to raise_error(InvalidDirectoryEntry, /Le modèle de données/)
    end

    # Refused rather than skipped over: a directory that publishes an entry the
    # rules refuse says something about that directory, where quietly asking the
    # next one would hide it until a correspondent rejected the message.
    it 'refuses on the first service it retained, without falling back on the next' do
      allow(dsd).to receive(:data_services).and_return([build(:data_service, id: 'service-de-test'), service])

      expect { directory.data_service(type.id, 'FI') }.to raise_error(InvalidDirectoryEntry)
    end

    it 'raises on a country the directory holds no provider for' do
      allow(dsd).to receive(:data_services).and_raise(CommonServicesError.new('vide', code: 'DSD:ERR:0001'))

      expect { directory.data_service(type.id, 'DE') }.to raise_error(CountryCodeNotFound, /DE/)
    end

    it 'lets an outage through rather than reporting it as an unknown country' do
      allow(dsd).to receive(:data_services).and_raise(CommonServicesError, 'annuaire injoignable')

      expect { directory.data_service(type.id, 'DE') }.to raise_error(CommonServicesError, /injoignable/)
    end
  end

  # `translating` names a refusal with a key rather than a sentence, and only
  # composes it once a directory has refused: nothing static ties the two.
  it 'says every refusal it translates' do
    refused = File.read('app/models/directories/common_services.rb')
      .scan(/'(models\.directories(?:\.[a-z_]+)+)'/).flatten.uniq

    expect_said(refused)
  end
end
