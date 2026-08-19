class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |table|
      # L'instant et la nature de ce qu'on consigne. Le journal est en ajout
      # seul : aucune ligne n'est jamais reprise, donc pas de `updated_at`.
      table.datetime :occurred_at, null: false
      table.string :event_type, null: false
      table.string :ebms_action

      # Les identifiants de corrélation que le chapitre 4.8 énumère. Ce sont eux
      # qui permettent de recoudre un échange à partir de traces éparses — les
      # nôtres, celles de la passerelle, celles du correspondant.
      table.string :conversation_id
      table.string :exchange_id
      table.string :message_id
      table.string :request_id
      table.string :response_id

      # Les deux coins, avec leur schéma d'identifiant : un SIRET nu ne désigne
      # personne hors de France.
      table.string :requesting_authority_id
      table.string :requesting_authority_scheme
      table.string :providing_authority_id
      table.string :providing_authority_scheme

      # Le fournisseur de service français qui a appelé notre API. Aucun
      # chapitre ne le nomme — il est en deçà de la frontière — mais sans lui on
      # ne sait pas au nom de qui l'échange a eu lieu.
      table.string :evidence_requester_id

      table.string :procedure_code
      table.string :evidence_type_id

      # Données personnelles, chiffrées au repos. `evidence_subject_key` l'est en
      # mode déterministe pour rester interrogeable : l'article 17 existe pour
      # qu'on puisse répondre à « quelles données de cette personne ont circulé ».
      table.text :evidence_subject
      table.string :evidence_subject_key

      # L'empreinte de la pièce, jamais la pièce.
      table.string :evidence_digest
      table.string :mime_type

      table.string :edm_error_code
      table.text :detail

      table.datetime :created_at, null: false
    end

    add_index :audit_events, :conversation_id
    add_index :audit_events, :occurred_at
    add_index :audit_events, :evidence_subject_key
  end
end
