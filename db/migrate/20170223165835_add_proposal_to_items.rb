class AddProposalToItems < ActiveRecord::Migration[5.0]
  def change
    add_reference :items, :proposal, foreign_key: true
  end
end
