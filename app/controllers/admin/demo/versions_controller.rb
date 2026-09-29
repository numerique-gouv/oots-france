module Admin
  module Demo
    # The first screen of the demonstration: the operator picks the line the
    # walk plays, and each card leads to the sign-in page under that line.
    #
    # Nothing is written here and no directory is asked: the address of the
    # page a card leads to is what carries the choice, until an identification
    # opens a journey in it.
    class VersionsController < Admin::BaseController
      def index
        @specifications = EdmSpecification::SPOKEN
      end
    end
  end
end
