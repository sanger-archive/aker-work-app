class MoveCommentFromWorkOrderToJob < ActiveRecord::Migration[5.1]
  def change
    remove_column :work_orders, :close_comment, :string
    add_column :jobs, :close_comment, :string
  end
end
