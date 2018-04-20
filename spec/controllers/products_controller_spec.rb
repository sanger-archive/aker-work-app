require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  let!(:user) { setup_user }

  let(:catalogue) { create(:catalogue) }
  let(:project) do
    proj = double(:project, id: 17, cost_code: 'S1234-0')
    allow(StudyClient::Node).to receive(:find).with(proj.id).and_return([proj])
    proj
  end
  let(:product) { create(:product, catalogue: catalogue, description: "Bake cakes") }
  let(:processes) do
    tats = [5,11]
    process_classes = [:genotyping, nil]
    (0..1).map do |i|
      pro = create(:process, TAT: tats[i], name: "pro_#{i}", process_class: process_classes[i])
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

  let(:work_plan) { create(:work_plan, project_id: project.id) }

  def setup_user(name = "user")
    user = OpenStruct.new(email: "#{name}@sanger.ac.uk", groups: ['world'])
    allow(controller).to receive(:check_credentials)
    allow(controller).to receive(:current_user).and_return(user)
    return user
  end

  describe "#before_action" do
    context "when the work order exists, but product does not" do
      it "throws record not found exception" do
        params = { id: work_plan.id, product_id: 'nonsense'}
        expect(WorkPlan).to receive(:find).with(work_plan.id.to_s)
        expect { get :show_product_inside_work_plan, params: params }
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
    context "when the product exists, but work order does not" do
      it "throws record not found exception" do
        params = { id: 'nonsense', product_id: product.id}
        expect{ get :show_product_inside_work_plan, params: params }
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#show_product_inside_work_plan" do

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
          { name: pro.name, id: pro.id, links: pro.build_available_links, path: pro.build_default_path,
            tat: pro.TAT, process_class: pro.process_class_human }
        end

        expect(r[:product_processes]).to eq(JSON.parse(product_processes.to_json, symbolize_names: true))
      end
    end

    context 'when the work plan has the specified product selected' do
      let!(:alt_modules) do
        processes.each_with_index.map do |pro, i|
          mod = create(:aker_process_module, name: "module_#{i}B", aker_process_id: pro.id)
          create(:aker_process_module_pairings, to_step_id: mod.id, default_path: false, aker_process: pro)
          create(:aker_process_module_pairings, from_step_id: mod.id, default_path: false, aker_process: pro)
          mod
        end
      end

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
          option_for_module = alt_modules[i].to_custom_hash.merge(selected_value: "").reject{|k| ((k == :min_value) || (k==:max_value))}
          path_for_process = [option_for_module]
          { name: pro.name, id: pro.id, links: pro.build_available_links, path: path_for_process,
            tat: pro.TAT, process_class: pro.process_class_human }
        end
        expect(r[:product_processes]).to eq(JSON.parse(product_processes.to_json, symbolize_names: true))
      end
    end

  end

  describe '#modules_unit_price' do
    let(:prices) { [11,5] }

    before do
      stub_billing    
      get :modules_unit_price, params: { id: work_plan.id, module_ids: modules.map(&:id).join('-') }
    end

    let(:body) { JSON.parse(response.body, symbolize_names: true) }

    context 'when the modules and the cost code are correct' do
      def stub_billing
        cost_code = project.cost_code
        modules.zip(prices) do |mod, price|
          allow(BillingFacadeClient).to receive(:get_cost_information_for_module).with(mod.name, cost_code).and_return(BigDecimal(price))
        end
      end
    
      it 'should return no errors' do
        expect(body[:errors]).to be_empty
      end

      it 'should return the total unit price' do
        total = BigDecimal(prices[0]+prices[1])
        expect(body[:unit_price]).to eq(total.to_s)
      end
    end

    context 'when the billing service cannot give a price for the modules and cost code' do
      def stub_billing
        allow(BillingFacadeClient).to receive(:get_cost_information_for_module).and_return(nil)
      end

      it 'should return an appropriate error' do
        expect(body[:errors].length).to eq(1)
        expect(body[:errors].first).to eq("The following modules are not valid for cost code #{project.cost_code}: #{modules.map(&:name)}")
      end

      it 'should not return a unit price' do
        expect(body[:unit_price]).to be_nil
      end
    end
  end
end
