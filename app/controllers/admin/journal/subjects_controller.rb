module Admin
  module Journal
    # The question article 17 exists for: which of this person's data travelled.
    class SubjectsController < BaseController
      def show
        @search = SubjectSearch.from(params)
        @events = @search.events.includes(:conversation).to_a
      end
    end
  end
end
