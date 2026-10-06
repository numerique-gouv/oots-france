module ConnectivityTesting
  # Asks a connectivity test towards one party of the PMode the gateway has
  # loaded, or towards every party when `party` names none: records each test
  # pending and hands its submission to a job. Only what the PMode declares and
  # can address, whatever the form posted; a party whose test is pending is
  # left to it.
  class RequestTests < ApplicationInteractor
    def call
      chosen.each do |party|
        test = ConnectivityTest.request(party)
        SubmitConnectivityTestJob.perform_later(test.id, test.requested_at) if test
      end
    end

    private

    def chosen
      parties = context.parties.select(&:addressable?)

      context.party.present? ? parties.select { |party| party.name == context.party } : parties
    end
  end
end
