class PermissionTableChanges < ActiveRecord::Migration[5.0]
  def change
  	add_column :permissions, :permission_type, :string, null: false

  	ActiveRecord::Base.transaction do |t|
  	  AkerPermissionGem::Permission.all.each do |p|
  	  	[
  	  	  [:r, 'read'], [:w, 'write'], [:x, 'sender']
  	  	].each do |column, new_value|
  	  	  if p.send(column)
  	  	    p.dup.update_attributes!(permission_type: new_value)
  	  	  end
  	  	end
  	  	p.destroy
  	  end
  	end

  	remove_column :permissions, :r
  	remove_column :permissions, :w
  	remove_column :permissions, :x
  end
end
