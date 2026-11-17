# The identity API Particulier matches a person on: France's national policy
# on identity matching, which chapter 2.1 §3.3 leaves to the Data Service —
# « The natural person attributes received match the ones held by Data Service
# following the national policy on identity matching ».
#
# Built from the subject of the request where it already holds all the
# endpoint needs — the sex, and the place of birth as a code of the Code
# officiel géographique, without which a person born in France is not found
# and the empty list would be false —; otherwise from the identity
# FranceConnect+ certified on the preview space, once the identity check of
# chapter 4.9 §2, step 18, has found it to be the subject of the request. A
# place written as a name is never resolved.
#
# One given name, the first: the endpoint takes no more.
class PivotIdentity < Data.define(:family_name, :given_name, :year, :month, :day, :sex, :birth_commune)
  # `Gender-CodeList` in its two profiles — `1` is « male », `2` « female » —
  # and the `gender` FranceConnect+ publishes. Every other code says neither.
  SEXES = {
    'Male' => 'M', '1' => 'M', 'male' => 'M',
    'Female' => 'F', '2' => 'F', 'female' => 'F',
  }.freeze

  # The shape FranceConnect publishes a French `birthplace` in: « le code INSEE
  # du lieu de naissance sur 5 chiffres (ou une chaîne vide si la personne est
  # née à l'étranger). Une lettre peut être présente pour les personnes nées en
  # corse » (https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-scope-fc/).
  # A European user's `birthplace` is free text from their eIDAS node, taken
  # only where it has that shape.
  # Not the `99` series of the Code officiel géographique, which names a
  # country: the endpoint wants no place for a person born abroad.
  COMMUNE = /\A(?!99)(\d{2}|2A|2B)\d{3}\z/

  # None where the request does not say the sex, or names no commune by its code.
  def self.from_request(person)
    identity = from(person.family_name, person.given_name, person.date_of_birth, person.gender, person.place_of_birth)
    identity if identity.complete? && identity.birth_commune
  end

  # None where FranceConnect+ says neither sex. A `birthplace` that is no
  # commune by its code — empty for a French identity born abroad, free text
  # for a European one — sends no place: a European user born in France is
  # then not found.
  def self.from_france_connect(identity)
    found = from(identity.family_name, identity.given_name, identity.birthdate, identity.gender,
      identity.place_of_birth)
    found if found.complete?
  end

  def self.from(family_name, given_names, date_of_birth, gender, place)
    year, month, day = date_of_birth.to_s.split('-')

    new(family_name:, given_name: given_names.to_s.split.first, year:, month:, day:, sex: SEXES[gender],
      birth_commune: commune(place))
  end
  private_class_method :from

  def self.commune(place)
    code = place.to_s.strip
    code if code.match?(COMMUNE)
  end
  private_class_method :commune

  def complete? = sex.present?

  # The parameters of `GET /v3/mesri/statut_etudiant/identite`, as its OpenAPI
  # description names them. No place where none is known: « Ne pas remplir si
  # la personne est née à l'étranger ».
  def to_query(recipient)
    {
      nomNaissance: family_name, 'prenoms[]': given_name, anneeDateNaissance: year, moisDateNaissance: month,
      jourDateNaissance: day, sexeEtatCivil: sex, codeCogInseeCommuneNaissance: birth_commune, recipient:,
    }.compact
  end
end
