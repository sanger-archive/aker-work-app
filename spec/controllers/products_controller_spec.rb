require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  def setup_user(name = "user")
    user = OpenStruct.new(email: "#{name}@sanger.ac.uk", groups: ['world'])
    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(user)
    return user
  end

  describe "#before_action" do
    before do
      @user = setup_user
    end
    context "when the work order exists, but product does not" do
      it "throws record not found exception" do
        work_plan = create(:work_plan)
        params = { id: work_plan.id, product_id: 'nonsense'}
        expect(WorkPlan).to receive(:find).with(work_plan.id.to_s)
        expect{ get :show_product_inside_work_plan, params: params}
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
    context "when the product exists, but work order does not" do
      it "throws record not found exception" do
        catalogue = create(:catalogue)
        product = create(:product, catalogue: catalogue)
        params = { id: 'nonsense', product_id: product.id}
        expect{ get :show_product_inside_work_plan, params: params}
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#show_product_inside_work_plan" do
    before do
      @user = setup_user
    end

    let(:catalogue) { create(:catalogue) }
    let(:project) do
      proj = double(:project, id: 17, cost_code: 'S1234-0')
      allow(StudyClient::Node).to receive(:find).with(proj.id).and_return([proj])
      proj
    end
    let(:product) { create(:product, catalogue: catalogue, description: "Bake cakes") }
    let(:processes) do
      tats = [5,11]
      (0..1).map do |i|
        pro = create(:process, TAT: tats[i], name: "pro_#{i}")
        create(:product_process, product: product, aker_process: pro, stage: i)
        pro
      end
    end
    let!(:modules) do
      processes.each_with_index.map do |pro, i|
        mod = create(:aker_process_module, name: "module_#{i}", aker_process_id: pro.id)
        create(:aker_process_module_pairings, to_step_id: mod.id, default_path: true, aker_process: pro)
        create(:aker_process_module_pairings, from_step_id: mod.id, default_path: true, aker_process: pro)
        mod
      end
    end

    let!(:alt_modules) do
      processes.each_with_index.map do |pro, i|
        mod = create(:aker_process_module, name: "module_#{i}B", aker_process_id: pro.id)
        create(:aker_process_module_pairings, to_step_id: mod.id, default_path: false, aker_process: pro)
        create(:aker_process_module_pairings, from_step_id: mod.id, default_path: false, aker_process: pro)
        mod
      end
    end

    let(:work_plan) { create(:work_plan, project_id: project.id) }

    context 'when the work plan has no product' do
      it "should return the work orders product info with the default path" do
        params = { id: work_plan.id, product_id: product.id}

        get :show_product_inside_work_plan, params: params

        r = JSON.parse(response.body, symbolize_names: true)
        expect(r[:name]).to eq product.name
        expect(r[:description]).to eq product.description
        expect(r[:availability]).to eq product.availability
        expect(r[:cost_code]).to eq project.cost_code
        expect(r[:total_tat]).to eq (processes[0].TAT + processes[1].TAT)

        product_processes = processes.map do |pro|
          { name: pro.name, id: pro.id, links: pro.build_available_links, path: pro.build_default_path }
        end

        expect(r[:product_processes].to_json).to eq(product_processes.to_json)
      end
    end

    context 'when the work plan has the specified product selected' do
      let!(:work_orders) do
        processes.each_with_index.map do |pro, i|
          wo = create(:work_order, work_plan: work_plan, process: pro, order_index: i)
          WorkOrderModuleChoice.create!(work_order: wo, aker_process_modules_id: alt_modules[i].id, position: 0)
          wo
        end
      end

      let(:work_plan) { create(:work_plan, project_id: project.id, product_id: product.id) }

      it "should return the work orders product info with the selected path" do
        params = { id: work_plan.id, product_id: product.id}

        get :show_product_inside_work_plan, params: params

        r = JSON.parse(response.body, symbolize_names: true)
        expect(r[:name]).to eq product.name
        expect(r[:description]).to eq product.description
        expect(r[:availability]).to eq product.availability
        expect(r[:cost_code]).to eq project.cost_code
        expect(r[:total_tat]).to eq (processes[0].TAT + processes[1].TAT)

        product_processes = processes.each_with_index.map do |pro, i|
          { name: pro.name, id: pro.id, links: pro.build_available_links, path: [alt_modules[i].to_custom_hash] }
        end
        expect(r[:product_processes].to_json).to eq(product_processes.to_json)
      end
    end

  end
end