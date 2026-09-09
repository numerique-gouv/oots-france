require 'cgi'

module FakeFranceConnect
  # The three pages the European path shows an user, condensed: the country,
  # picked at the bridge; an identity of that country, which the node presents
  # and the bridge never sees; and the consent page of FranceConnect+, in
  # English for a European user.
  # back/apps/eidas-bridge/src/views/interaction.ejs
  # back/apps/core-fcp/src/views/consent.ejs
  # back/apps/core-fcp/src/handlers/verify/core-fcp-eidas-verify.handler.ts
  module Pages
    def self.countries(action, codes)
      buttons = codes.map { |code| button('country', code, Identities.country_name(code)) }

      layout('Choose your country', form(action, buttons))
    end

    def self.identities(action, identities)
      buttons = identities.map { |identity| button('identity', identity.key, identity.label) }

      layout('Choose a test identity', form(action, buttons))
    end

    # What the consent page of FranceConnect+ does: list the data about to be
    # transmitted, and take an explicit « Continue ».
    def self.consent(action, claims)
      rows = claims.map { |name, value| "<li>#{escape(name)}: #{escape(value)}</li>" }
      body = '<p>The following data will be transmitted to the service provider.</p>' \
             "<ul>#{rows.join}</ul>" \
             "#{form(action, [button('consent', 'yes', 'Continue')])}"

      layout('Authorise the transmission of your data', body)
    end

    # The wording the core answers a malformed `/authorize` with, and the whole
    # of what the browser gets: no redirection, no code.
    # back/libs/oidc-provider/src/exceptions/oidc-provider-authorize-params.exception.ts
    def self.error(error, description)
      layout('Error', "<p>#{escape(error)}</p><p>#{escape(description)}</p>")
    end

    # The only page of the fake in French: FranceConnect+ shows this one to
    # every user, European or not, and the sentence is its own.
    def self.logged_out
      layout('Déconnexion', '<p>Vous êtes bien déconnecté, vous pouvez fermer votre navigateur.</p>',
        lang: 'fr')
    end

    def self.button(field, value, label)
      "<button type=\"submit\" name=\"#{escape(field)}\" value=\"#{escape(value)}\">#{escape(label)}</button>"
    end

    def self.form(action, controls)
      "<form method=\"post\" action=\"#{escape(action)}\">#{controls.join}</form>"
    end

    def self.layout(title, body, lang: 'en')
      "<!DOCTYPE html><html lang=\"#{escape(lang)}\"><head><meta charset=\"utf-8\">" \
        "<title>#{escape(title)}</title></head><body><h1>#{escape(title)}</h1>#{body}</body></html>"
    end

    def self.escape(value) = CGI.escapeHTML(value.to_s)
  end
end
