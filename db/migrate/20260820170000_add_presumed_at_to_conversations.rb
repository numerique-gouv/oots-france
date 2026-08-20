class AddPresumedAtToConversations < ActiveRecord::Migration[8.1]
  def change
    # Chapitre 4.4 : un portail ne doit pas traiter une réponse « to which it
    # already received a response ». Un échange expiré n'en a reçu aucune — le
    # balayage a présumé —, et rien dans les colonnes ne distinguait cette
    # présomption d'une vraie réponse portant le même code.
    add_column :conversations, :presumed_at, :datetime
  end
end
