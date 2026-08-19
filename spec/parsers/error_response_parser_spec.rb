require 'rails_helper'

RSpec.describe ErrorResponseParser do
  subject(:error) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')).body }

  # The code is the invariant of the end-to-end scenario: it can only come from
  # a message the gateway delivered.
  it 'reads the EDM code' do
    expect(error.code).to eq('EDM:ERR:0004')
  end

  it 'reads the message that accompanies it' do
    expect(error.message).to eq('Object not found')
  end

  # The code distinguishes the eight errors of the TDD, which the message alone
  # conflates — two of them read "Object not found" to a human.
  it 'describes itself by code and message together' do
    expect(error.description).to eq('EDM:ERR:0004 : Object not found')
  end

  it 'is not a request for a preview' do
    expect(error).not_to be_preview_required
  end

  describe 'an authorisation error carrying a preview location' do
    subject(:error) { RetrievedMessageParser.new(envelope).body }

    let(:envelope) { built_envelope('erreurAutorisationRequise') }

    it 'is recognised as a request for a preview' do
      expect(error).to be_preview_required
    end

    it 'reads where to send the user' do
      expect(error.preview_location).to eq('https://previsualisation.example.si/espace?jeton=abc')
    end

    # The type is `rs:AuthorizationExceptionType`, whose prefix is bound in the
    # document and could be anything. The severity says the same thing without
    # that trap, and R-EDM-ERR-C022 is what ties it to the preview slot.
    it 'decides on the severity, never on the prefixed type' do
      renamed = envelope.gsub('rs:AuthorizationExceptionType', 'autre:AuthorizationExceptionType')

      expect(RetrievedMessageParser.new(renamed).body).to be_preview_required
    end
  end

  # R-EDM-ERR-C026 requires the attribute, but nothing guarantees a
  # correspondent obeys, and stumbling on its absence would turn a reportable
  # error into an internal one.
  describe 'an error whose code attribute is missing' do
    subject(:error) { RetrievedMessageParser.new(built_envelope('erreurSansCode')).body }

    it 'reads no code rather than failing' do
      expect(error.code).to be_nil
    end

    it 'falls back on the message alone to describe itself' do
      expect(error.description).to eq('Missing Authorization')
    end
  end

  # `R-EDM-REQ-C073` et son équivalent pour l'erreur imposent une adresse sur
  # l'agent classé `ERRP`, et n'y imposent que le pays : c'est de là que se lit
  # le pays d'où le refus est venu.
  it 'reads the country the refusal came from' do
    expect(error.provider_country).to eq('FR')
  end
end
