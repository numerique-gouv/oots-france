# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# The account a developer opens the administration space with. Not created in
# production: this password is in the repository, so seeding it there would open
# the space to whoever has read the file. A real deployment makes its own
# account in `rails console` — docs/espace_administration.md says how.
#
# Assigned rather than only created, so that replaying the seed restores the
# advertised password on an account whose own was changed.
if Rails.env.production?
  # Said rather than passed over in silence: without it, nothing distinguishes
  # a seed that deliberately skipped from one that died before reaching here.
  puts "Aucun compte d'administration n'est créé en production : voir docs/espace_administration.md"
else
  administrator = Administrator.find_or_initialize_by(email: 'admin@example.com')
  administrator.password = 'Administration-2026'
  administrator.save!

  puts "Compte d'administration : #{administrator.email} / Administration-2026"
end
