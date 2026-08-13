# The data services holding an evidence type in a country, as the Data Service
# Directory returns them (chapter 3.1.4).
#
# `sdg:AccessService/sdg:Identifier` is the ebCore party identifier of the
# gateway, and its `schemeID` the scheme naming it: OOTS runs no SMP, so
# chapter 4.7 has this identifier matched against a statically configured
# PMode, which is what says at which address the party answers.
class DataServicesResponseParser < CommonServicesResponseParser
  DATA_SERVICE = "./rim:Slot[@name='DataServiceEvidenceType']/rim:SlotValue/sdg:DataServiceEvidenceType".freeze

  def providers = @read

  private

  def read
    records(DATA_SERVICE).flat_map { |declared| all(declared, './sdg:AccessService').map { |service| build(service) } }
  end

  def build(service)
    publisher = at(service, './sdg:Publisher')

    EvidenceProvider.new(
      identifier: identity(publisher, "L'identité du fournisseur annoncé par l'annuaire"),
      access_point: access_point(service),
      descriptions: by_language(all(publisher || service, './sdg:Name')),
      address: address(publisher),
    ).validate!("Le fournisseur annoncé par l'annuaire", error: CommonServicesError)
  end

  def identity(scope, subject)
    identifier = scope && at(scope, './sdg:Identifier')

    EbmsIdentity.new(id: identifier&.text&.strip, type_id: attribute(identifier, 'schemeID'))
      .validate!(subject, error: CommonServicesError)
  end

  def access_point(service)
    identifier = at(service, './sdg:Identifier')

    AccessPoint.new(id: identifier&.text&.strip, type_id: attribute(identifier, 'schemeID'))
      .validate!("Le point d'accès annoncé par l'annuaire", error: CommonServicesError)
  end

  # Read and validated rather than left to its default, which is France: the
  # provider this describes is a foreign one, and silently calling it French
  # would put the wrong country in the message built from it.
  def address(publisher)
    country = publisher && text_at(publisher, './sdg:Address/sdg:AdminUnitLevel1')

    Address.new(country: country&.strip)
      .validate!("L'adresse du fournisseur annoncé par l'annuaire", error: CommonServicesError)
  end
end
