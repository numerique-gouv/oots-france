# « FR - Student status (MESRI) », the evidence France serves from API
# Particulier, in either of two distributions — the one the request asks for
# (chapter 4.5.2 §2.1): the object `data` of `GET
# /v3/mesri/statut_etudiant/identite`, as API Particulier returned it, in
# `application/json`; or the attestation API Particulier generates itself,
# QR code and verification code included, in `application/pdf`. No data model
# of the first exists at the Semantic Repository (chapter 3.3.3 §3.5), so it
# names none — `R-EDM-RESP-C045` holds that a mere warning —, and the second,
# unstructured, may name none (chapter 4.5.1 §3.5).
#
# Read back for the preview space when the data is what is served: the space
# then shows it rather than offering a document (chapter 4.10 §5.1, step 20,
# « The evidence may need to be transformed to allow the user to preview it.
# For example, if it is in a structured format »). The attestation is offered
# as a PDF, and never read back.
class StudentStatus
  # `LanguageCode`, upper case, which `R-EDM-RESP-C026` (FATAL) holds
  # `sdg:Language` to. The attestation is in French whatever the request asks:
  # « Lack of support for a requested language SHALL NOT be treated as an
  # error condition » (chapter 4.5.1 §3.5).
  LANGUAGE = 'FR'.freeze
  DATA = ServedDistribution.new(format: 'application/json', language: LANGUAGE, title: 'Statut étudiant')
  ATTESTATION = ServedDistribution.new(format: EvidenceType::PDF, language: LANGUAGE,
    title: 'Attestation de statut étudiant')
  DISTRIBUTIONS = [DATA, ATTESTATION].freeze

  # The data where the request asks for it, alone or beside the PDF; the
  # attestation where it asks for the PDF alone; none otherwise. One
  # distribution per response: chapter 4.5.2 §2.1 asks for « at least one of
  # the requested distributions », and §4 leaves the others to a « may ».
  def self.distribution_for(evidence_type)
    DISTRIBUTIONS.find { |distribution| evidence_type.requests?(distribution.format) }
  end

  # The actual issuer of the evidence — chapter 4.5.2 §1, « the Issuing
  # Authority of the Evidence Metadata shall be used to indicate the actual
  # issuer of the Evidence » —: the ministry of higher education, by the SIRET
  # of its head office, under the scheme France names its own organisations
  # with. Its names are values of a message, under `lang` codes of
  # `LanguageCode`, and reach a correspondent, not a screen.
  def self.issuer
    EvidenceProvider.new(
      identifier: EbmsIdentity.new(id: '11004401300040', type_id: IdentifierScheme::FRENCH),
      descriptions: {
        'FR' => "Ministère de l'Enseignement supérieur, de la Recherche et de l'Espace",
        'EN' => 'Ministry of Higher Education, Research and Space',
      },
    )
  end

  # Whether `data` says who the person is and where they are admitted, in the
  # shape this class reads — whether they are enrolled or only admitted
  # above all, which an answer silent on it would not show as either.
  def self.readable?(data)
    data.is_a?(Hash) && data['identite'].is_a?(Hash) && data['admissions'].is_a?(Array) &&
      data['admissions'].all? { |admission| readable_admission?(admission) }
  end

  def self.readable_admission?(admission)
    admission.is_a?(Hash) && admission['est_inscrit'].in?([true, false]) &&
      admission.values_at('etablissement_etudes', 'regime_formation').all? { |part| part.nil? || part.is_a?(Hash) }
  end
  private_class_method :readable_admission?

  Identity = Data.define(:family_name, :given_name, :date_of_birth)
  Admission = Data.define(:institution, :institution_code, :start_date, :end_date, :enrolled, :scheme,
    :commune_code)

  def initialize(document)
    @data = JSON.parse(document)
  end

  def identity
    read = @data.fetch('identite', {})
    Identity.new(family_name: read['nom_naissance'], given_name: read['prenom'], date_of_birth: read['date_naissance'])
  end

  def admissions = @data.fetch('admissions', []).map { |admission| admission_from(admission) }

  private

  def admission_from(read)
    institution = read['etablissement_etudes'] || {}

    Admission.new(
      institution: institution['nom'], institution_code: institution['uai'], start_date: read['date_debut'],
      end_date: read['date_fin'], enrolled: read['est_inscrit'], scheme: read.dig('regime_formation', 'libelle'),
      commune_code: read['code_cog_insee_commune'],
    )
  end
end
