module TestServicesHelper
  def make_work_order
    @work_order = double(:work_order)
  end

  def made_up_uuid
    SecureRandom.uuid
  end

  def made_up_barcode
    @barcode_counter += 1
    "AKER-#{@barcode_counter}"
  end


  def make_material
    double('material', id: made_up_uuid)
  end

  def make_container
    container = double("container", slots: make_slots, barcode: made_up_barcode, id: made_up_uuid)
    allow(container).to receive(:material_id=)
    allow(container).to receive(:save)
    container
  end


  def stub_matcon
    @barcode_counter = 0
    @materials = []

    allow(MatconClient::Material).to receive(:destroy).and_return(true)

    allow(MatconClient::Material).to receive(:create) do |args|
      [args].flatten.map do
        material = make_material
        @materials.push(material)
        material
      end
    end
  end

  def make_slots
    'A:1 A:2 A:3 B:1 B:2 B:3'.split.map do |address|
      slot = double('slot', address: address)
      allow(slot).to receive(:material_id=)
      slot
    end
  end

  def make_work_order
    @work_order = double(:work_order)
  end


end

