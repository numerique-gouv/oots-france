namespace :oots do
  desc 'Rend un exemplaire de chaque message OOTS, corps et entête ebMS, dans le répertoire donné'
  task :messages, [:destination] => :environment do |_tache, arguments|
    destination = arguments[:destination]
    raise ArgumentError, 'Usage : rake "oots:messages[répertoire]"' if destination.blank?

    # Des valeurs par défaut, et non des variables obligatoires : la validation
    # Schematron tourne sur un runner nu, sans passerelle ni fichier
    # d'environnement, et n'a besoin que de la structure des messages. Une
    # configuration réelle, si elle est là, l'emporte.
    ENV['SUFFIXE_IDENTIFIANTS_DOMIBUS'] ||= 'oots.eu'
    ENV['IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'AP_FR_01'
    ENV['TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS'] ||= 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'
    ENV['IDENTIFIANT_FOURNISSEUR_FRANCAIS'] ||= '00000000000001'
    ENV['NOM_FOURNISSEUR_FRANCAIS'] ||= 'Direction interministérielle du numérique'

    Oots::SpecimenMessages.new(destination).write_all
    puts "Messages écrits dans #{destination}"
  end
end
