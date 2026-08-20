require 'rails_helper'

RSpec.describe ExpireConversationsJob do
  # Chapter 4.4: an Online Procedure Portal « shall generate a timeout error in
  # case the Data Service did not reply … within a configured timeout interval ».
  # Nothing arrives to trigger it, which is why a sweep has to look.
  #
  # Which exchanges get picked is `Conversation.expired`'s business, and its own
  # spec walks that matrix; what only this level shows is that the sweep hands
  # them to `expire!`, and that one bad row does not carry away the rest.
  it 'closes an exchange no answer settled in time' do
    overdue = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 1.minute)

    described_class.perform_now

    expect(overdue.reload).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0005')
  end

  # `find_each` walks in primary-key order, so an exception left to propagate
  # would strand every exchange behind the offending one — for ever, where the
  # row fails every time and the cron replays the same walk each minute.
  #
  # The row is broken through `update_column`, which is how it would break in
  # production too: not by a write the validations saw, but by data drifting
  # under them.
  it 'expires the exchanges behind one the validations refuse' do
    doomed = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 2.minutes)
    doomed.update_column(:country_code, nil)
    next_in_line = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 1.minute)

    described_class.perform_now

    expect(next_in_line.reload.status).to eq('failed')
    expect(doomed.reload.status).to eq('sent')
  end

  # The net has to hold what the validations never see either: `expire!` runs
  # callbacks, and `NormalisesCountryCode` upcasing a string whose encoding has
  # been corrupted raises `ArgumentError`. Such a value cannot be stored to
  # provoke it for real — PostgreSQL refuses it — so the raise stands in for it.
  it 'expires the exchanges behind one that fails outside Active Record' do
    doomed = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 2.minutes)
    next_in_line = create(:conversation, :sent, created_at: Settings.requester_timeout.ago - 1.minute)
    allow(doomed).to receive(:expire!).and_raise(ArgumentError, 'input string invalid')
    sweep = Conversation.where(id: [doomed.id, next_in_line.id])
    allow(Conversation).to receive(:expired).and_return(sweep)
    allow(sweep).to receive(:find_each).and_yield(doomed).and_yield(next_in_line)

    described_class.perform_now

    expect(next_in_line.reload.status).to eq('failed')
  end
end
