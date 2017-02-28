class AddProposalIdToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :proposal_id, :integer
  end
end
