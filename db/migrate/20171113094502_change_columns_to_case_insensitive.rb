class ChangeColumnsToCaseInsensitive < ActiveRecord::Migration[5.0]
  def up
    enable_extension 'citext'
    change_column :catalogues, :lims_id, :citext, null: false
    change_column :permissions, :permitted, :citext
    change_column :work_orders, :owner_email, :citext

    Catalogue.find_each { |c| c.save! if c.sanitise_lims }
    AkerPermissionGem::Permission.find_each { |p| p.save! if p.sanitise_permitted }
    WorkOrder.where.not(owner_email: nil).find_each { |wo| wo.save! if wo.sanitise_owner }
  end

  def down
    change_column :catalogues, :lims_id, :string, null: true
    change_column :permissions, :permitted, :string
    change_column :work_orders, :owner_email, :string
  end
end
