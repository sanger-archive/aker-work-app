require "rails_helper"

RSpec.describe Developers::WorkOrderMailer, type: :mailer do
  describe "dispatch_failed" do
    let(:que_job) { DispatchWorkOrder.enqueue(work_order_id: work_order.id) }
    let(:work_order) { create(:work_order_with_jobs) }
    let(:message) { "Some reason why it could not be dispatched" }
    let(:mail) do
      Developers::WorkOrderMailer
        .with(
            que_job: que_job,
            work_order: work_order,
            exception: StandardError.new(message)
          )
        .dispatch_failed
    end

    it "renders the headers" do
      expect(mail.subject).to eq("(test) Dispatch failed for Work Order #{work_order.id}")
      expect(mail.to).to eq([Rails.configuration.akerdev_email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match(message)
    end
  end

end
