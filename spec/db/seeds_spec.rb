require 'rails_helper'

# The demonstration set names constants — procedure codes, conversation statuses
# — from inside a block `Rails.env.development?` guards, so nothing else in this
# suite ever evaluates it: a constant renamed everywhere but here stays green
# through RSpec and fails the end-to-end workflow, the only one that runs
# `db:seed`. This example is what makes that a second rather than four minutes.
RSpec.describe 'db/seeds.rb' do
  it 'replays without raising' do
    expect { replay }.not_to raise_error
  end

  it 'opens one exchange per status the console can show' do
    replay

    expect(Exchange.distinct.pluck(:status)).to match_array(Exchange::STATUSES)
  end

  # The demonstration is the only data the console is ever read against by hand,
  # so a column it never fills is a page nobody has looked at. Asserted on the
  # two the code fills differently rather than on the whole row: the evidence
  # identifier rides on the document, so an answer that carried one names it and
  # a deferral names nothing.
  it 'names the evidence on the responses that carried one, and on no other event' do
    replay

    named = AuditEvent.where.not(evidence_identifier: nil)

    expect(named.pluck(:event_type).uniq).to match_array(%w[response_sent response_received])
    expect(named.count).to eq(4)
  end

  # `detail` is filled on the way in as well as on the way out: a response that
  # broke a rule of chapter 4.6 names it there, and the exchange was settled all
  # the same — nothing is refused over one.
  it 'names on an arriving response the rule of chapter 4.6 it broke' do
    replay

    breached = AuditEvent.where(event_type: 'response_received').filter_map(&:detail)

    expect(breached).to contain_exactly(a_string_starting_with('R-EDM-RESP-C002'))
    expect(Exchange.find_by(country_code: 'CZ')).to have_attributes(status: 'delivered')
  end

  # The correlation of chapter 4.8: a request and the answer to it name one
  # request identifier, which is the whole of what following an exchange means.
  #
  # Presence asserted before equality, and not `compact`ed away: a list holding
  # one identifier and one nil has exactly as many distinct values as a list
  # holding the same identifier twice, so dropping the nils would pass the very
  # regression this guards against.
  it 'gives the events of one exchange the identifiers that tie them together' do
    replay

    answered = AuditEvent.where(event_type: %w[request_received response_sent])
      .where(exchange_id: Exchange.find_by(incoming: true, status: 'delivered', country_code: 'BE').exchange_id)
      .index_by(&:event_type)

    expect(answered.keys).to contain_exactly('request_received', 'response_sent')
    expect(answered.values.map(&:request_id)).to all(be_present)
    expect(answered.values.map(&:request_id).uniq.size).to eq(1)
  end

  # One action per message, and the three the TDD define: asserted on the whole
  # set rather than on a sample, a wrong constant on one line of the table
  # being exactly the kind of fault a sample walks past.
  it 'names every message by the action it carried' do
    replay

    circulated = AuditEvent::SENT_BY_FRANCE + AuditEvent::RECEIVED_BY_FRANCE
    pairs = AuditEvent.where(event_type: circulated).distinct.pluck(:event_type, :ebms_action)

    expect(pairs.size).to eq(circulated.size)
    expect(pairs.to_h).to eq(
      'request_sent' => EbmsAction::EXECUTE_QUERY_REQUEST,
      'request_received' => EbmsAction::EXECUTE_QUERY_REQUEST,
      'response_sent' => EbmsAction::EXECUTE_QUERY_RESPONSE,
      'response_received' => EbmsAction::EXECUTE_QUERY_RESPONSE,
      'error_sent' => EbmsAction::EXCEPTION_RESPONSE,
      'error_received' => EbmsAction::EXCEPTION_RESPONSE,
    )
  end

  # The answer's own identifier, which fewer events carry than the request's,
  # and which the two sides do not spell alike — the demonstration would teach
  # one shape for both if nothing held them apart.
  it 'names the answer only where France or its correspondent built one' do
    replay

    expect(AuditEvent.where.not(response_id: nil).distinct.pluck(:event_type))
      .to contain_exactly('response_sent', 'response_received', 'error_sent', 'answer_not_sent')

    expect(AuditEvent.where.not(request_id: nil).pluck(:request_id)).to all(start_with('urn:uuid:'))
    expect(AuditEvent.where.not(response_id: nil).pluck(:response_id)).to all(match(/\A\h{8}-(\h{4}-){3}\h{12}\z/))
  end

  # The answer the gateway would not take names the request it answered, read
  # back from the arrival rather than drawn again: a `find_by` that missed would
  # leave the one line holding that answer correlated to nothing.
  it 'ties the answer the gateway refused to the request it was answering' do
    replay

    unsent = AuditEvent.find_by(event_type: 'answer_not_sent')
    arrived = AuditEvent.find_by(exchange_id: unsent.exchange_id, event_type: 'request_received')

    expect(unsent.request_id).to be_present
    expect(unsent.request_id).to eq(arrived.request_id)
    expect(unsent.response_id).to be_present
  end

  # Chapter 4.5.1 lets the evidence subject be an organisation, which has
  # neither a given name nor a date of birth: the demonstration carries one, so
  # that the journal page is read at least once against a line whose subject
  # search is legitimately unavailable.
  it 'records an organisation as an evidence subject, and gives it no canonical key' do
    replay

    about_an_organisation = AuditEvent.where(event_type: 'request_received', evidence_subject_key: nil)

    expect(about_an_organisation.count).to eq(1)
    expect(about_an_organisation.first.evidence_subject).to include('legal_name')
  end

  # The seed narrates what it wrote, which the suite has no use for.
  def replay
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    spoken = $stdout
    $stdout = StringIO.new

    load Rails.root.join('db/seeds.rb')
  ensure
    $stdout = spoken
  end
end
