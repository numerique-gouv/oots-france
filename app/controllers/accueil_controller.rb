# The service's front page, presenting to a French administration what the
# service does and what joining it asks. Its header leads to its sections, to
# its contact and to the administration space.
class AccueilController < ApplicationController
  include ChosenLanguage

  def index; end

  private

  def presentation_page? = true
end
