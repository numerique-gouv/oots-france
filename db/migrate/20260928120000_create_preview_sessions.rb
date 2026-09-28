# What France keeps of one preview, from the address it issues to the answer
# to the second request (chapter 4.9 §2, steps 8 and 26). The columns carrying
# the subject are encrypted by the model and emptied once the answer has gone
# or the address has expired; the row itself goes at T2 + T3.
class CreatePreviewSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :preview_sessions do |t|
      the_address(t)
      the_subject(t)
      t.timestamps
    end

    add_index :preview_sessions, :token, unique: true
    add_index :preview_sessions, :location, unique: true
  end

  private

  def the_address(table)
    %i[token location exchange_id conversation_id specification].each { |name| table.string name, null: false }
    table.string :status, null: false, default: 'pending'
    table.datetime :issued_at, null: false
    %i[first_visited_at second_request_sent_at].each { |name| table.datetime name }
    table.string :answering_exchange_id
    table.text :return_location
    table.string :return_method
  end

  def the_subject(table)
    %i[first_request second_request second_message_id document evidence_id evidence_issued_at decision]
      .each { |name| table.text name }
  end
end
