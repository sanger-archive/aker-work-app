require 'rails_helper'

RSpec.describe UpdateOrderService do
  def make_uuid
    SecureRandom.uuid
  end

  def make_set(size=6)
    uuid = make_uuid
    s = double(:set, uuid: uuid, id: uuid, meta: { 'size' => size })
    allow(SetClient::Set).to receive(:find).with(s.uuid).and_return([s])
    return s
  end

  def make_proposal
    proposal = double('proposal', name: 'Operation Wolf', cost_code: 'S1001', id: 42)
    allow(StudyClient::Node).to receive(:find).with(proposal.id).and_return([proposal])
    return proposal
  end

  def make_product(attrs=nil)
    @c1 = create(:catalogue)
    x = { catalogue_id: @c1.id }
    x.merge!(attrs) if attrs
    create(:product, x)
  end

  def order_at_step(step)
    attrs = { status: step.to_s, owner_email: "user@sanger.ac.uk" }

    return create(:work_order, attrs) if step==:set
    @original_set = make_set
    @clone_set = make_set
    attrs[:original_set_uuid] = @original_set.uuid
    attrs[:set_uuid] = @clone_set.uuid

    return create(:work_order, attrs) if step==:proposal
    @proposal = make_proposal
    attrs[:proposal_id] = @proposal.id

    return create(:work_order, attrs) if step==:product
    @product = make_product
    attrs[:product_id] = @product.id
    attrs[:cost_per_sample] = 17
    attrs[:total_cost] = attrs[:cost_per_sample]*@clone_set.meta['size']

    return create(:work_order, attrs)
  end

  describe "#perform" do
    context "when the work order is already active" do
      before do
        wo = order_at_step(:active)
        @messages = {}
        params = {}
        @service = UpdateOrderService.new(params, wo, @messages)
      end

      it "blocks the operation" do
        expect(@service.perform(:summary)).to eq false
        expect(@messages[:error]).to include('work order has already been issued')
      end
    end

    context "when the work order has a set" do
      before do
        allow(BillingFacadeClient).to receive(:validate_cost_code?).and_return(true)
        @wo = order_at_step(:product)
      end

      it "blocks changing the original set to a new set" do
        params = {
          'original_set_uuid' => make_set().uuid
        }
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:set)).to eq false
        expect(@wo.original_set_uuid).to eq(@original_set.uuid)
        expect(@wo.set_uuid).to eq(@clone_set.uuid)
        expect(messages[:error]).to include('locked')
      end

      it "doesn't error if the original set is specified" do
        params = {
          'original_set_uuid' => @original_set.uuid
        }
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:set)).to eq true
        expect(@wo.original_set_uuid).to eq(@original_set.uuid)
        expect(@wo.set_uuid).to eq(@clone_set.uuid)
        expect(messages[:error]).to be_nil
      end
    end

    context "when a new set is selected" do
      def load_set_with_materials(set_id, material_ids)
        set_contents = material_ids.map { |mid| double(:material, id: mid, _id: mid) }
        s = double(:set, uuid: set_id, id: set_id, materials: set_contents, meta: { 'size' => set_contents.size})
        allow(SetClient::Set).to receive(:find_with_materials).with(set_id).and_return([s])
        s
      end

      def load_materials(material_ids, availability)
        materials = material_ids.zip(availability).map do |mid, av|
          double(:material, id: mid, _id: mid, attributes: { 'available' => av })
        end
        result_set = double(:result_set, has_next?: false, to_a: materials)
        allow(MatconClient::Material).to receive(:where).with("_id" => {"$in" => material_ids})
          .and_return(double(:query, result_set: result_set))
        materials
      end

      before do
        @wo = order_at_step(:set)
        @chosen_set = make_set
        @cloned_set = make_set
        allow(@chosen_set).to receive(:create_locked_clone).and_return(@cloned_set)
        @material_ids = ['f32501fd-765d-40b1-81df-7d881c0ab9ed', '47426618-6aa4-4d9b-893f-929c7d44b783']
        load_set_with_materials(@chosen_set.uuid, @material_ids)
        @messages = {}
      end

      let(:params) {{'original_set_uuid' => @chosen_set.uuid }}

      context "when some material is unavailable" do
        before do
          load_materials(@material_ids, [true, false])
          @result = UpdateOrderService.new(params, @wo, @messages).perform(:set)
        end

        it "should return false" do
          expect(@result).to eq false
        end

        it "should have an error indicating the materials are unavailable" do
          expect(@messages[:error]).to match(/materials.*available/)
        end

        it "should not save the cloned set in the work order" do
          expect(@wo.set).to be_nil
        end
      end

      context "when the materials are all available" do
        before do
          load_materials(@material_ids, [true, true])
          @result = UpdateOrderService.new(params, @wo, @messages).perform(:set)
        end

        it "should return true" do
          expect(@result).to eq true
        end

        it "should not have an error" do
          expect(@messages[:error]).to be_nil
        end

        it "should save the cloned set in the work order" do
          expect(@wo.set).to eq(@cloned_set)
        end
      end
    end

    context "when work order is at proposal step" do
      before do
        @wo = order_at_step(:proposal)
      end

      it "should refuse a later step" do
        params = {}
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(false)
        expect(messages[:error]).to include('project')
      end

      context "when the billing service validates the proposal" do
        before do
          allow(BillingFacadeClient).to receive(:validate_cost_code?).and_return(true)
        end
        it "should accept a proposal id" do
          proposal = make_proposal
          params = { 'proposal_id' => proposal.id }
          messages = {}
          expect(UpdateOrderService.new(params, @wo, messages).perform(:proposal)).to eq(true)
          expect(messages[:error]).to be_nil

          expect(@wo.proposal_id).to eq(proposal.id)
          expect(@wo.status).to eq('product')
        end
      end

      context "when the billing service does not validate the proposal" do
        it "should fail if the cost code of the proposal is not validated by the billing service" do
          proposal = make_proposal
          params = { 'proposal_id' => proposal.id }
          allow(BillingFacadeClient).to receive(:validate_cost_code?).and_return(false)
          messages = {}
          expect(UpdateOrderService.new(params, @wo, messages).perform(:proposal)).to eq(false)
          expect(messages[:error]).to include('Billing')
        end
      end
    end

    context "when work order is at product step" do
      before do
        @wo = order_at_step(:product)
        aker_process = Aker::Process.create(name: 'process', TAT: 1)
        Aker::ProcessModule.create(name: 'module1', aker_process_id: aker_process.id)
        Aker::ProcessModule.create(name: 'module2', aker_process_id: aker_process.id)
      end

      it "should accept a product" do
        expect(@wo.total_cost).to be_nil
        product = make_product

        unit_cost = BigDecimal.new(17)
        allow(BillingFacadeClient).to receive(:get_unit_price)
          .with(@wo.proposal.cost_code, product.name).and_return(unit_cost)

        params = { product_id: product.id, product_options: 'module1,module2'}
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(true)
        expect(messages[:error]).to be_nil

        expect(@wo.product).to eq(product)
        expect(@wo.total_cost).to eq(@clone_set.meta['size']*@wo.cost_per_sample)
        expect(@wo.status).to eq('summary')
      end

      it "should refuse a later step" do
        params = {}
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:summary)).to eq(false)
        expect(messages[:error]).to include('product')
      end

      it "should fail if the cost cannot be calculated" do
        product = make_product

        unit_cost = nil
        allow(BillingFacadeClient).to receive(:get_unit_price)
          .with(@wo.proposal.cost_code, product.name).and_return(unit_cost)

        params = { 'product_id' => product.id }
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(false)
        expect(messages[:error]).to include('cost')
      end

      context "when a product is selected" do
        let(:product) { make_product}

        context "given we previously selected a proposal" do
          let(:proposal) { @wo.proposal }
          let(:cost_code) { @wo.proposal.cost_code }
          let(:unit_price) { BigDecimal.new(17) }

          context "when the unit price is verified by the billing service" do
            it "should display the total cost for the product" do
              allow(BillingFacadeClient).to receive(:get_unit_price).with(cost_code, product.name)
                  .and_return(unit_price)

              expect(BillingFacadeClient).to receive(:get_unit_price)
                .with(cost_code, product.name)

              params = { product_id: product.id, product_options: 'module1,module2'}

              messages = {}
              expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(true)

            end
          end
          context "when the unit price is not verified by the billing service" do
            it "should fail and display an error message" do
              allow(BillingFacadeClient).to receive(:get_unit_price).with(cost_code, product.name)
                  .and_return(nil)

              params = { 'product_id' => product.id }
              messages = {}
              expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(false)
              expect(messages[:error]).to include('missing product cost')
            end
          end
        end
      end
    end

    context "when work order is at summary step" do
      before do
        @wo = order_at_step(:summary)
        allow(@wo).to receive(:send_to_lims)

        aker_process = Aker::Process.create(name: 'process', TAT: 1)
        Aker::ProcessModule.create(name: 'module1', aker_process_id: aker_process.id)
        Aker::ProcessModule.create(name: 'module2', aker_process_id: aker_process.id)
      end

      it "should have a total cost that can be obtained from unit prices and num samples" do
        expect(@wo.total_cost).to eq(@wo.cost_per_sample * @wo.set.meta['size'])
      end

      it "should refuse if the product is suspended" do
        @wo.product.update_attributes(availability: false)
        params = {}
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:summary)).to eq(false)
        expect(messages[:notice]).to include('suspended')
        expect(@wo).not_to have_received(:send_to_lims)

        expect(@wo.status).to eq('summary')
      end

      it "should be able to proceed" do
        params = {}
        messages = {}
        allow(@wo).to receive(:generate_submitted_event)
        expect(UpdateOrderService.new(params, @wo, messages).perform(:summary)).to eq(true)
        expect(messages[:error]).to be_nil
        expect(messages[:notice]).to include('created')

        expect(@wo).to have_received(:send_to_lims)
        expect(@wo.status).to eq('active')
      end

      it "should let you alter an earlier step" do
        product = make_product
        expect(@wo.product).not_to eq(product)

        unit_cost = BigDecimal.new(17)
        allow(BillingFacadeClient).to receive(:get_unit_price)
          .with(@wo.proposal.cost_code, product.name).and_return(unit_cost)

        params = { product_id: product.id, product_options: 'module1,module2'}

        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:product)).to eq(true)
        expect(messages[:error]).to be_nil
        expect(@wo.product).to eq(product)

        expect(@wo).not_to have_received(:send_to_lims)
        expect(@wo.status).not_to eq('active')
      end

      it "should fail gracefully if send_to_lims fails" do
        allow(@wo).to receive(:send_to_lims).and_raise "Limsplosion"
        params = {}
        messages = {}
        expect(UpdateOrderService.new(params, @wo, messages).perform(:summary)).to eq(false)
        expect(messages[:error]).to include('LIMS failed')

        expect(@wo).to have_received(:send_to_lims)
        expect(@wo.status).not_to eq('active')
      end
    end

  end
end
