# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # `beneficiaire` carries the encrypted beneficiary token in the query string
  # of /requete/pieceJustificative, and an unfiltered query string is written to
  # the request log in clear.
  :beneficiaire,
  # The authorization code FranceConnect+ returns the user with, which the
  # request log would otherwise write in clear on the return address. Anchored,
  # where every entry above matches a substring: a bare `:code` would take
  # `codeDemarche` and `codePays` with it, and the support of FranceConnect asks
  # for the `state` and the call's parameters to be readable.
  /\Acode\z/
]
