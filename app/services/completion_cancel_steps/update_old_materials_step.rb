class UpdateOldMaterialsStep

  attr_reader :materials, :materials_before_changes

  def initialize(job, msg)
    @job = job
    @msg = msg
  end

  # Step 3 - Update old materials
  def up
    @materials = []
    @materials_before_changes = []
    @msg[:job][:updated_materials].each do |updated_params|
      uuid = updated_params[:_id]
      updated_params.delete(:_id)
      material = MatconClient::Material.find(uuid)
      previous_state = Hash[updated_params.map{ |k,v| [k, material.attributes[k]] }]
      material.update_attributes(updated_params)
      @materials.push(material)
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
