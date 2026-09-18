# The return address of the demonstration procedure, walked without a departure:
# a code replayed from a history, or one obtained in another browser.
UNREQUESTED_RETURN = '/demo/franceconnect/retour_connexion?code=un-code&state=un-etat-invente'.freeze

Étantdonné("FranceConnect+ qui refuse l'échange du code par {string}") do |error|
  stub_request(:post, "#{browser_france_connect_issuer}#{FranceConnectStubs::PATHS[:token_endpoint]}")
    .to_return(status: 400, body: { error: }.to_json)
end

Quand("l'administrateur s'identifie depuis la carte du faux FranceConnect+") do
  visit admin_demo_root_path
  sign_in_from_card('fake')
end

Quand("l'administrateur revient de FranceConnect+ sur une identification que ce navigateur n'a pas demandée") do
  visit UNREQUESTED_RETURN
end

# The two ways the reason could read wrong: a label introducing a field
# FranceConnect+ did not answer, and a full stop the alert added behind one the
# sentence already carried.
Alors('la page affiche le refus sans libellé vide ni point doublé') do
  expect(page.find('.fr-alert').text.squish).not_to include('—', 'voir', '..')
end
