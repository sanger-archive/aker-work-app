class UpdateOldMaterialsStep

  def initialize(work_order, msg)
    @work_order = work_order
    @msg = msg
  end

  # Step 3 - Update old materials
  def up
    @materials_before_changes = []
    @msg[:work_order][:updated_materials].each do |updated_params|
      uuid = updated_params[:_id]
      updated_params.delete(:_id)
      material = MatconClient::Material.find(uuid)
      before_change = material.clone
      material.update_attributes(updated_params)
      @materials_before_changes.push(before_change)
     end
  end

  def down
    if @materials_before_changes
      @materials_before_changes.each do |old_data|
        remote = MatconClient::Material.find(old_data.id)
        remote.update_attributes(old_data.serialize)
      end
    end
  end
end