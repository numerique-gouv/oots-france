module Admin
  module Journal
    # Nothing new about access: `Admin::BaseController` already carries the
    # guard, and the journal opens to the same account as the rest of the console.
    class BaseController < Admin::BaseController
    end
  end
end
