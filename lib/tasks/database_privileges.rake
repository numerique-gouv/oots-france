namespace :db do
  desc 'Pose le rôle applicatif restreint : lecture et écriture partout, sauf la réécriture du journal'
  task privileges: :environment do
    role = Settings.application_database_role

    if role.nil?
      puts 'Aucun rôle applicatif configuré : les processus se connectent en propriétaire.'
      next
    end

    ActiveRecord::Base.with_connection { |connection| DatabasePrivileges.new(connection, **role).apply! }

    puts "Rôle #{role[:username]} posé, #{DatabasePrivileges::APPEND_ONLY_TABLES.join(', ')} en ajout seul."
  end
end
