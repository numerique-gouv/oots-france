namespace :oots do
  desc 'Rend un exemplaire de chaque message OOTS, corps et entête ebMS, dans le répertoire donné'
  task :messages, %i[destination specification] => :environment do |_tache, arguments|
    destination = arguments[:destination]
    raise ArgumentError, 'Usage : rake "oots:messages[répertoire,oots-edm:vX.Y]"' if destination.blank?

    announced = arguments[:specification]
    specification = announced.blank? ? EdmSpecification.preferred : EdmSpecification.find(announced)
    raise ArgumentError, "Version inconnue : #{announced}" if specification.nil?

    # Defaults, and not mandatory variables: the Schematron validation runs on a
    # bare runner, with no gateway and no environment file, and needs nothing but
    # the structure of the messages. A real configuration, where there is one,
    # wins.
    ENV['SUFFIXE_IDENTIFIANTS_DOMIBUS'] ||= 'oots.eu'
    ENV['IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'AP_FR_01'
    ENV['TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR'
    ENV['IDENTIFIANT_FOURNISSEUR_FRANCAIS'] ||= '00000000000001'
    ENV['NOM_FOURNISSEUR_FRANCAIS'] ||= 'Direction interministérielle du numérique'

    Oots::SpecimenMessages.new(destination, specification:).write_all
    puts "Messages #{specification} écrits dans #{destination}"
  end
end
