class UpdateOldMaterialsStep

  attr_reader :materials_before_changes

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
      previous_state = Hash[updated_params.map{ |k,v| [k, material.attributes[k]] }]
      material.update_attributes(updated_params)
      materials_before_changes.push({id: uuid, attrs: previous_state})
     end
  end

  def down
    if materials_before_changes
      materials_before_changes.reverse_each do |previous|
        remote = MatconClient::Material.find(previous[:id])
        remote.update_attributes(previous[:attrs])
      end
    end
  end
end
