require 'rails_helper'

# The wiring the controller and the job stopped carrying. Each step gives itself
# the infrastructure it uses, so nothing outside has to be kept in step with it
# — and nothing else in the suite would notice a default that changed class,
# every other spec injecting its collaborator.
#
# The three most wanted live on `ApplicationInteractor` and are asked of it
# directly; what only two steps want is asked of one of those two.
RSpec.describe 'Les dépendances par défaut des interactors' do
  # `send`, these being private: they are for the steps that inherit them, not
  # for a caller. What is public is the keyword a caller passes instead.
  describe 'celles que porte ApplicationInteractor' do
    subject(:interactor) { Class.new(ApplicationInteractor).new(context) }

    let(:context) { Interactor::Context.build }

    it 'donne la passerelle, le générateur et le journal' do
      expect([interactor.send(:gateway), interactor.send(:uuid), interactor.send(:audit_trail)])
        .to match([an_instance_of(DomibusClient), an_instance_of(UuidGenerator), an_instance_of(AuditTrail)])
    end

    it 'honore ceux qu\'on lui passe' do
      trail = instance_double(AuditTrail)
      passed = Class.new(ApplicationInteractor).new(Interactor::Context.build(audit_trail: trail))

      expect(passed.send(:audit_trail)).to be(trail)
    end

    # Sur le contexte et non en mémo d'instance : deux étapes d'une même chaîne
    # doivent frapper leurs identifiants avec le même générateur.
    it 'les dépose sur le contexte, pour toute la chaîne' do
      expect { interactor.send(:uuid) }.to change(context, :uuid).from(nil).to(an_instance_of(UuidGenerator))
    end
  end

  # The setting is stubbed and not read from the environment: what is under
  # test is the wiring, and `DONNEES_REQUETEURS` is one of the variables the CI
  # does not give the unit suite.
  #
  # The `EvidenceRequesterNotFound` is the point: the real directory was built
  # and consulted, where a nil one would have raised `NoMethodError`.
  it 'se donne un annuaire des requéteurs quand on ne lui en passe pas' do
    allow(Settings).to receive(:evidence_requesters_data).and_return({})

    result = EvidenceRequest::ResolveRequester.call(requester_id: 'inconnu')

    expect(result.requesters).to be_a(Directories::EvidenceRequesters)
    expect(result.error[:key]).to eq(:unknown_requester)
  end

  it 'honore celui qu\'on lui passe' do
    requesters = instance_double(Directories::EvidenceRequesters, find: build(:evidence_requester))

    result = EvidenceRequest::ResolveRequester.call(requester_id: '12345678901234', requesters:)

    expect(result.requesters).to be(requesters)
  end

  # Le partage, vu d'une vraie étape : celle-ci se sert du générateur que la
  # précédente a déposé, ce qui est ce qui rend un message sortant comparable
  # dès qu'une spec fige le générateur.
  it 'partage un seul générateur d\'identifiants sur toute une chaîne' do
    context = Interactor::Context.build(conversation_id: nil, procedure_code: '00',
      country_code: 'FI', requester: build(:evidence_requester))

    EvidenceRequest::OpenExchange.call(context)
    minted = context.uuid

    expect(minted).to be_a(UuidGenerator)
    expect { EvidenceRequest::OpenExchange.call(context) }.not_to change { context.uuid }.from(minted)
  end
end
