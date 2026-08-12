class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |table|
      # L'identifiant qui voyage dans l'entête ebMS et qui rapproche une réponse
      # de la requête qui l'a provoquée. C'est la seule prise : la passerelle ne
      # rend rien d'autre qui permette de faire le lien.
      table.string :conversation_id, null: false
      table.string :status, null: false, default: 'pending'

      # De quoi reprendre l'échange et retrouver à qui répondre. Aucune donnée
      # personnelle ici : le bénéficiaire vit dans le jeton que le requêteur
      # fournit, et il n'a pas à être conservé pour que la conversation avance.
      table.string :procedure_code, null: false
      table.string :country_code, null: false
      table.string :evidence_requester_id, null: false

      # L'espace de prévisualisation du fournisseur étranger, quand il exige
      # que l'usager s'y rende avant de délivrer le justificatif.
      table.text :preview_location

      table.string :edm_error_code
      table.text :error_description

      table.datetime :settled_at

      table.timestamps
    end

    add_index :conversations, :conversation_id, unique: true
    add_index :conversations, :status
  end
end
