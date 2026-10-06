# Reads the verdict of one submitted connectivity test a few seconds after it
# left, and again while it stays pending, for its first two minutes: the gateway
# settles a test message in seconds — it never retries one —, and the page
# waiting on it should not wait for the minute of `ReadConnectivityVerdictsJob`.
# That sweep stays the net behind it, and the one that closes a test past
# `ConnectivityTest::VERDICT_DEADLINE`.
class FollowConnectivityTestJob < ApplicationJob
  queue_as :default

  INTERVAL = 3.seconds
  WINDOW = 2.minutes

  def perform(test_id)
    test = ConnectivityTest.find_by(id: test_id)
    return unless test&.pending? && test.message_id

    ConnectivityTesting::ReadVerdict.call(test:)

    self.class.set(wait: INTERVAL).perform_later(test.id) if test.pending? && test.requested_at > WINDOW.ago
  end
end
