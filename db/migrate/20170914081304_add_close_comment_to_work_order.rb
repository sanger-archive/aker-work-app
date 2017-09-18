class AddCloseCommentToWorkOrder < ActiveRecord::Migration[5.0]
  def change
    add_column :work_orders, :close_comment, :string
  end
end
