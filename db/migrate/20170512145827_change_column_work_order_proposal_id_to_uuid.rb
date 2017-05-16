class ChangeColumnWorkOrderProposalIdToUuid < ActiveRecord::Migration[5.0]
  def change
    change_column :work_orders, :proposal_id, :uuid
  end
end
