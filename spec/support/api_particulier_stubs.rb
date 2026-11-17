# API Particulier as the specs answer for it, and the requests for « FR -
# Student status (MESRI) » they send France.
#
# `MARTIN_JACQUES` is the `data` the sandbox returned on 2026-11-16 for
# `civility_etudiant_inscrit.yml` of the mocks of `datagouv/apistration`:
# Martin Jacques, born 2004-01-01 in Paris 2e, `M`.
module ApiParticulierStubs
  STUDENT_STATUS_TYPE =
    'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/4daaf228-43fd-43fc-9148-a416c9a22464'.freeze

  MARTIN_JACQUES = {
    'identite' => { 'nom_naissance' => 'Martin', 'prenom' => 'Jacques', 'date_naissance' => '2004-01-01' },
    'admissions' => [{
      'date_debut' => '2024-10-01', 'date_fin' => '2025-08-31', 'est_inscrit' => true,
      'regime_formation' => { 'libelle' => 'formation initiale', 'code' => 'RF1' },
      'code_cog_insee_commune' => '92000',
      'etablissement_etudes' => { 'uai' => '0330023W', 'nom' => 'Université Paris Nanterre' },
    }],
  }.freeze

  # Every query of CA1, the sex and the place aside.
  MARTIN_JACQUES_QUERY = {
    'nomNaissance' => 'Martin', 'prenoms' => ['Jacques'], 'anneeDateNaissance' => '2004', 'moisDateNaissance' => '01',
    'jourDateNaissance' => '01', 'recipient' => '13002526500013',
  }.freeze

  ATTESTATION = "%PDF-1.5\n% attestation de statut étudiant\n".b.freeze

  # Where the staging put the attestation on 2026-11-16: the host France called.
  def attestation_link = "#{Settings.api_particulier_url}/api/attestations/ItNld0cWUJSeM"

  def student_status_endpoint = /\A#{Regexp.escape(Settings.api_particulier_url + ApiParticulierClient::PATH)}(\?|\z)/

  def stub_student_status(status: 200, data: MARTIN_JACQUES, body: nil)
    stub_request(:get, student_status_endpoint).to_return(
      status:, body: body || { data:, links: {}, meta: {} }.to_json, headers: { 'Content-Type' => 'application/json' },
    )
  end

  # The answer to a call carrying `X-Generate-Proof: pdf`, and the PDF at the
  # end of its link.
  def stub_attested_student_status(link: attestation_link, status: 200, pdf: ATTESTATION)
    stub_request(:get, student_status_endpoint).with(headers: ApiParticulierClient::PROOF).to_return(
      body: { data: MARTIN_JACQUES, links: { attestation_pdf: link }.compact, meta: {} }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
    stub_request(:get, link).to_return(status:, body: pdf, headers: { 'Content-Type' => 'application/pdf' }) if link
  end

  def attestation_downloaded = a_request(:get, attestation_link)

  def stub_student_status_unknown
    stub_student_status(status: 404, body: { errors: [{ code: '25003', title: 'Entité non trouvée' }] }.to_json)
  end

  # The one call made, with the query it carried.
  def student_status_asked(query)
    a_request(:get, student_status_endpoint).with(query: query)
  end

  def student_status_never_asked = a_request(:get, student_status_endpoint)

  # A request of the captured envelope for the student status: Martin Jacques,
  # with the sex and the place given, in the distributions given. `nil` leaves
  # an element out.
  # A fresh request identifier each, chapter 4.4 refusing one used before.
  def student_status_request(flag: 'false', line: :v2_0, **)
    requested(line) do |body|
      student_status_body(flagged(body, flag), **).sub(PreviewRequests::REQUEST_ID, "\\1urn:uuid:#{SecureRandom.uuid}")
    end
  end

  # The body of a request rewritten into one for the student status. Through
  # patterns on the elements, so that a body rewritten already is rewritten
  # again rather than left as it was.
  def student_status_body(body, gender: 'Male', place: '75102', given_name: 'Jacques', date_of_birth: '2004-01-01',
                          family_name: 'Martin', formats: [StudentStatus::DATA.format])
    for_student_status(body.dup.force_encoding(Encoding::UTF_8), formats)
      .sub(%r{<sdg:FamilyName>[^<]*</sdg:FamilyName>}) { "<sdg:FamilyName>#{family_name}</sdg:FamilyName>" }
      .sub(%r{<sdg:GivenName>[^<]*</sdg:GivenName>}) { "<sdg:GivenName>#{given_name}</sdg:GivenName>" }
      .gsub(%r{<sdg:(PlaceOfBirth|Gender)>[^<]*</sdg:\1>}, '')
      .sub(%r{<sdg:DateOfBirth>[^<]*</sdg:DateOfBirth>}) do
        "<sdg:DateOfBirth>#{date_of_birth}</sdg:DateOfBirth>" +
          (place ? "<sdg:PlaceOfBirth>#{place}</sdg:PlaceOfBirth>" : '') +
          (gender ? "<sdg:Gender>#{gender}</sdg:Gender>" : '')
      end
  end

  def student_status_request_about_an_organisation(formats: [StudentStatus::DATA.format])
    envelope_with_body('requete') do |body|
      for_student_status(body.dup.force_encoding(Encoding::UTF_8), formats)
        .sub(%r{<rim:Slot name="NaturalPerson">.*?</rim:Slot>}m) { legal_person_slot }
        .sub(PreviewRequests::REQUEST_ID, "\\1urn:uuid:#{SecureRandom.uuid}")
    end
  end

  private

  def for_student_status(body, formats)
    distributions = formats.map { |format| "<sdg:DistributedAs><sdg:Format>#{format}</sdg:Format></sdg:DistributedAs>" }

    asking_for_type(body, STUDENT_STATUS_TYPE)
      .sub(%r{<sdg:DistributedAs>.*?</sdg:DistributedAs>}m) { distributions.join }
  end
end
