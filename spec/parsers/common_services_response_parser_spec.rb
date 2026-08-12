require 'rails_helper'

RSpec.describe CommonServicesResponseParser do
  # Both services answer 200 whatever happens, and chapter 3.6.2 requires the
  # body to be read regardless of the HTTP code: the status attribute is the
  # only thing that says whether the query succeeded.
  it 'reads the refusal from the document rather than from the transport' do
    body = common_services_answer('eb_requirements_vides').first

    expect { described_class.new(body) }
      .to raise_error(CommonServicesError, /EB:ERR:0001.*result set is empty/)
  end

  it 'carries the code so a refusal can be told from an outage' do
    body = common_services_answer('dsd_aucun_service_fr').first

    described_class.new(body)
  rescue CommonServicesError => e
    expect(e.code).to eq('DSD:ERR:0001')
  end

  it 'accepts a successful answer' do
    body = common_services_answer('eb_requirements_fr').first

    expect { described_class.new(body) }.not_to raise_error
  end

  it 'refuses an answer that does not echo the version we asked for' do
    body = common_services_answer('eb_requirements_fr').first

    expect { described_class.new(body.sub('oots-cs:v2.0', 'oots-cs:v1.0')) }
      .to raise_error(CommonServicesError, /a répondu en oots-cs:v1.0/)
  end

  # No slot at all is the v1.0 shape, which is what a service answers when no
  # `Accept-Version` reaches it. Unchecked, it would read as a success whose
  # slots are all missing — an empty answer rather than a version nobody agreed.
  it 'refuses an answer carrying no version at all, as the v1.0 shape does' do
    body = common_services_answer('eb_requirements_fr').first
      .sub(%r{<rim:Slot name="SpecificationIdentifier">.*?</rim:Slot>}m, '')

    expect { described_class.new(body) }.to raise_error(CommonServicesError, /une version sans nom/)
  end

  # Only the Evidence Broker makes `code` optional, so a refusal can legitimately
  # arrive without one and the message has to carry the whole meaning.
  it 'says what it can when the refusal carries no code' do
    body = common_services_answer('eb_requirements_vides').first.sub(/ code="[^"]*"/, '')

    expect { described_class.new(body) }.to raise_error(CommonServicesError, /result set is empty/)
  end

  # Neither is mandated by every service, and a refusal that names nothing at
  # all would otherwise reach the caller as an empty message.
  it 'falls back on the exception itself when it names nothing' do
    body = common_services_answer('eb_requirements_vides').first
      .sub(/ code="[^"]*"/, '').sub(/ message="[^"]*"/, '')

    expect { described_class.new(body) }.to raise_error(CommonServicesError, /L'annuaire a refusé : .*Exception/m)
  end

  it 'refuses something that is not a QueryResponse at all' do
    expect { described_class.new('<html><body>502 Bad Gateway</body></html>') }
      .to raise_error(CommonServicesError, /pas une QueryResponse/)
  end
end
