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
        work_order = create(:work_order)
        params = { id: work_order.id, product_id: 'nonsense'}
        expect(WorkOrder).to receive(:find).with(work_order.id.to_s)
        expect{ get :show_product_inside_work_order, params: params}
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
    context "when the product exists, but work order does not" do
      it "throws record not found exception" do
        catalogue = create(:catalogue)
        product = create(:product, catalogue: catalogue)
        params = { id: 'nonsense', product_id: product.id}
        expect{ get :show_product_inside_work_order, params: params}
          .to raise_exception(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#show_product_inside_work_order" do
    before do
      @user = setup_user
    end

    it "it return the work orders product info" do
      work_order = double(:work_order, id: 1)
      proposal = double(:proposal)
      catalogue = double(:catalogue)
      product = double(:product, id: 1, name: 'product1', catalogue: catalogue)
      process = double(:aker_process, id: 1)
      pairings = double(:aker_process_module_pairings)

      allow(work_order).to receive(:permitted?).and_return true
      allow(WorkOrder).to receive(:find).with(work_order.id.to_s).and_return work_order
      allow(Product).to receive(:find).with(product.id.to_s).and_return product

      allow(work_order).to receive(:proposal).and_return proposal
      allow(proposal).to receive(:cost_code).and_return 'S1234'
      allow(product).to receive(:processes).and_return [process]

      allow(Aker::ProcessModulePairings).to receive(:where).and_return(pairings)

      available_links = {"start":[{"name": "A","id": "1"}]};
      default_path = ['start', 'A']

      allow(product).to receive(:build_available_links).with(pairings).and_return available_links
      allow(product).to receive(:build_default_path).with(pairings).and_return default_path

      expect(product).to receive(:name).and_return(product.name)
      expect(product).to receive(:processes).and_return([process])

      unit_cost = BigDecimal.new(17)
      allow(BillingFacadeClient).to receive(:get_unit_price)
        .with(work_order.proposal.cost_code, product.name).and_return(unit_cost)

      params = { id: work_order.id, product_id: product.id}

      get :show_product_inside_work_order, params: params

      r = JSON.parse(response.body)
      expect(r["name"]).to eq 'product'
      expect(r["cost_code"]).to eq 'S1234'
      expect(r["unit_price"].to_s).to eq(unit_cost.to_s)
      expect(r["available_links"]).to eq(available_links.with_indifferent_access)
      expect(r["default_path"]).to eq(default_path)
    end

  end
end