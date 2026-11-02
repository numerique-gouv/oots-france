# The language a page rendered to a browser is read in: the one the header's
# selector last chose, kept in a cookie rather than in the session so that it
# outlives the `reset_session` of a sign-in and a sign-out, and French when
# nothing was chosen.
#
# Included controller by controller, never by `ApplicationController`: the
# requester's contract inherits from it, and answers in the default locale
# whatever cookie its caller carries.
module ChosenLanguage
  extend ActiveSupport::Concern

  LANGUAGES = %i[fr en].freeze
  COOKIE = :locale
  PARAMETER = 'locale'.freeze

  included do
    before_action :remember_chosen_language, if: -> { request.get? && params.key?(PARAMETER) }
    helper_method :language_switch_path if respond_to?(:helper_method)
  end

  def self.language(value) = value.to_s.to_sym.presence_in(LANGUAGES)

  def self.read(cookies) = language(cookies[COOKIE]) || I18n.default_locale

  private

  # Around the whole action and not as an `around_action`: the page a
  # `rescue_from` handler renders comes after the callbacks have unwound, and
  # would otherwise be rendered in the default locale.
  def process_action(...) = I18n.with_locale(ChosenLanguage.read(cookies)) { super }

  # The selector's link lands here, and is sent back to the same address
  # without the parameter, so that the address stays the page's own.
  def remember_chosen_language
    language = ChosenLanguage.language(params[PARAMETER])
    cookies.permanent[COOKIE] = { value: language, httponly: true, same_site: :lax } if language

    redirect_to address_without_choice, status: :see_other
  end

  def address_without_choice
    query = request.query_parameters.except(PARAMETER).to_query

    [request.path, query.presence].compact.join('?')
  end

  # The page a form's answer was rendered in has no address of its own: the
  # selector goes back to the page carrying the form, read off the `Referer` of
  # this host, and to the home page without one. Only the path is kept, so the
  # link never leaves this host. The current address is taken as Rails already
  # read it, never parsed again: a query it accepted may still be one `URI`
  # refuses.
  def language_switch_path(language)
    path, query = request.get? ? [request.path, request.query_parameters] : departure_from_referer
    "#{path}?#{query.merge(PARAMETER => language.to_s).to_query}"
  end

  def departure_from_referer
    referer = same_host_referer
    return [root_path, {}] if referer.nil?

    [referer.path.presence || root_path, Rack::Utils.parse_nested_query(referer.query)]
  rescue Rack::Utils::ParameterTypeError, Rack::Utils::InvalidParameterError
    [root_path, {}]
  end

  def same_host_referer
    referer = URI.parse(request.referer.to_s)
    referer if referer.host == request.host && referer.port == request.port
  rescue URI::InvalidURIError
    nil
  end
end
