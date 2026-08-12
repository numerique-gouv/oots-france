# The endpoint the Docker composition and the CI poll to know whether the
# application is answering.
class AccueilController < ApplicationController
  def index = render(plain: 'OOTS-France')
end
