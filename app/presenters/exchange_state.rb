# What a French service provider reads of an exchange it asked for, as the JSON
# the requester interface answers — the state of `GET /requete/:exchange_id`,
# and the ground the answer to a preview confirmation stands on.
#
# The EDM code travels with the state: a correspondent that refuses says why,
# and that reason is the only thing the caller can act on. So does the announced
# date, which chapter 4.5.2 exists to convey: « … the Online Procedure Portal
# may use this information to inform the user to pause the procedure and to
# return at a later point … ».
class ExchangeState
  # `preview_link`: the link the portal presents once it has confirmed a
  # preview, which the answer to that confirmation carries.
  def initialize(exchange, preview_link: nil)
    @exchange = exchange
    @preview_link = preview_link
  end

  def to_h
    {
      echange: exchange.exchange_id,
      conversation: exchange.conversation_id,
      statut: exchange.status,
      codeErreur: exchange.edm_error_code,
      **preview,
      **presented_link,
      dateDisponibilite: exchange.response_available_at&.iso8601,
    }.compact
  end

  private

  attr_reader :exchange, :preview_link

  # Chapter 4.9 v1.2.3 §5 sends a `POST` or a `PUT` with the return address in
  # its body, hence the third field.
  def presented_link
    return {} if preview_link.nil?

    {
      adressePrevisualisation: preview_link.address,
      methodePrevisualisation: preview_link.http_method,
      corpsPrevisualisation: preview_link.body,
    }
  end

  # Only while the exchange waits for the portal to confirm: past that, the
  # address is no longer one to send a user to. The descriptions are what
  # chapter 4.9 §5 has the portal build its launch page from, one per language
  # the correspondent wrote.
  def preview
    return {} unless exchange.preview_required?

    {
      adressePrevisualisation: exchange.preview_location,
      descriptionPrevisualisation: descriptions.presence,
    }
  end

  def descriptions
    Array(exchange.preview_descriptions).map do |described|
      { langue: described['language'], texte: described['text'] }
    end
  end
end
