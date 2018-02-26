require 'rails_helper'

describe ApplicationHelper do
  describe "#total_TAT" do
    it "calculates the total TAT" do

      catalogue = create(:catalogue)
      product = create(:product, catalogue: catalogue)

      process1 = Aker::Process.create!(name: 'process1', TAT: 4)
      process2 = Aker::Process.create!(name: 'process2', TAT: 5)
      pp1 = Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process1.id, stage: 1)
      pp2 = Aker::ProductProcess.create!(product_id: product.id, aker_process_id: process2.id, stage: 2)
      work_order = create(:work_order, product_id: product.id)
      expect(helper.total_TAT(work_order)).to eq 9
    end
  end
end