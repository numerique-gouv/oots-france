# Submits the test message of one connectivity test, so that the page asking
# for it answers without waiting on the gateway.
#
# `requested_at` ties the job to the request that enqueued it: a test settled
# and asked again since is another request, which has its own job.
class SubmitConnectivityTestJob < ApplicationJob
  queue_as :default

  def perform(test_id, requested_at)
    test = ConnectivityTest.find_by(id: test_id)
    return unless test && test.requested_at.round(6) == requested_at.round(6)

    ConnectivityTesting::SubmitTest.call(test:)
    FollowConnectivityTestJob.set(wait: FollowConnectivityTestJob::INTERVAL).perform_later(test.id) if test.message_id
  end
end
