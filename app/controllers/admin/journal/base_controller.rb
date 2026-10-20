module Admin
  module Journal
    # The one part of the console that shows other people's personal data, as
    # the exchanges recorded it: reserved to the administrators named in the list.
    class BaseController < Admin::BaseController
      before_action :require_named_administrator
    end
  end
end
