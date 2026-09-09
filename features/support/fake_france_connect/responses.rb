require 'json'
require 'uri'
require_relative 'pages'

module FakeFranceConnect
  # What the endpoints write into a WEBrick response, in one place: the
  # difference between a page and a redirection carries the whole of RG3 and
  # RG4, and it is not to be restated at each call site.
  module Responses
    CACHE = 'public, max-age=600'.freeze

    def json(response, payload)
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(payload)
    end

    def cacheable_json(response, payload, type)
      response['Content-Type'] = type
      response['Cache-Control'] = CACHE
      response.body = JSON.generate(payload)
    end

    def page(response, html, status: 200)
      response.status = status
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = html
    end

    # The refusal that redirects nowhere: HTTP 400, `invalid_request` and
    # « invalid parameter », which is all the core gives a malformed call.
    def error_page(response, error = 'invalid_request', description = 'invalid parameter')
      page(response, Pages.error(error, description), status: 400)
    end

    def redirect(response, uri, parameters)
      response.status = 302
      response['Location'] = "#{uri}#{uri.include?('?') ? '&' : '?'}#{URI.encode_www_form(parameters.compact)}"
      response.body = ''
    end

    def not_found(response)
      page(response, Pages.error('not_found', 'unknown endpoint'), status: 404)
    end
  end
end
