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
    # The name these pages carry, so that whoever meets one knows at a glance
    # that nothing here is FranceConnect+ or a member state's node.
    SERVICE = 'Mock eIDAS'.freeze

    # Enough style for the pages to be read and the buttons to be hit, embedded
    # rather than linked: the fake serves itself, on a machine that may have no
    # way out to the network, and a stylesheet it had to fetch would be one
    # more thing to fail. Deliberately **not** the DSFR — these pages play a
    # foreign portal and a member state's node, which wear no French State
    # livery, and the one reader they have is the operator driving the
    # demonstration.
    STYLE = <<~CSS.freeze
      :root { color-scheme: light dark; }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
        line-height: 1.5;
        color: #161616;
        background: #f6f6f6;
      }
      .banner {
        border-bottom: 1px solid #ddd;
        background: #fff;
        padding: 1rem 1.5rem;
      }
      .banner p { margin: 0; font-weight: 700; letter-spacing: .02em; }
      .banner span { display: block; font-weight: 400; font-size: .875rem; color: #666; }
      main {
        max-width: 34rem;
        margin: 0 auto;
        padding: 3rem 1.5rem 4rem;
        text-align: center;
      }
      h1 { font-size: 1.5rem; margin: 0 0 1.5rem; }
      p { margin: 0 0 1rem; }
      ul { list-style: none; padding: 0; margin: 0 0 2rem; text-align: left; }
      li {
        padding: .5rem .75rem;
        border-bottom: 1px solid #e5e5e5;
        display: flex;
        justify-content: space-between;
        gap: 1rem;
      }
      li:last-child { border-bottom: 0; }
      li b { font-weight: 400; color: #666; }
      form { display: flex; flex-direction: column; gap: .75rem; align-items: stretch; }
      button {
        font: inherit;
        min-height: 3rem;
        padding: .75rem 1.5rem;
        border: 1px solid #000091;
        border-radius: .25rem;
        background: #000091;
        color: #fff;
        cursor: pointer;
      }
      button:hover { background: #1212ff; border-color: #1212ff; }
      button:focus-visible { outline: 2px solid #0a76f6; outline-offset: 2px; }
      .card { background: #fff; border: 1px solid #e5e5e5; border-radius: .25rem; padding: 1.5rem; }
      .quiet { color: #666; font-size: .875rem; }
    CSS

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
      rows = claims.map { |name, value| "<li><b>#{escape(name)}</b><span>#{escape(value)}</span></li>" }
      body = '<p>The following data will be transmitted to the service provider.</p>' \
             "<ul class=\"card\">#{rows.join}</ul>" \
             "#{form(action, [button('consent', 'yes', 'Continue')])}"

      layout('Authorise the transmission of your data', body)
    end

    # The wording the core answers a malformed `/authorize` with, and the whole
    # of what the browser gets: no redirection, no code.
    # back/libs/oidc-provider/src/exceptions/oidc-provider-authorize-params.exception.ts
    def self.error(error, description)
      layout('Error', "<p>#{escape(error)}</p><p class=\"quiet\">#{escape(description)}</p>")
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

    # The step's own wording stays the `<h1>`: it is what the scenarios read to
    # know where they are, and what the user is being asked. The service name
    # sits above it, in the banner.
    def self.layout(title, body, lang: 'en')
      "<!DOCTYPE html><html lang=\"#{escape(lang)}\"><head><meta charset=\"utf-8\">" \
        '<meta name="viewport" content="width=device-width, initial-scale=1">' \
        "<title>#{SERVICE} — #{escape(title)}</title><style>#{STYLE}</style></head><body>" \
        "<header class=\"banner\"><p>#{SERVICE}" \
        '<span>Faux FranceConnect+ et passerelle eIDAS — pour les tests, aucune donnée réelle</span>' \
        "</p></header><main><h1>#{escape(title)}</h1>#{body}</main></body></html>"
    end

    def self.escape(value) = CGI.escapeHTML(value.to_s)
  end
end
