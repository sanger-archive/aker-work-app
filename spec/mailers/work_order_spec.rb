require "rails_helper"

RSpec.describe WorkOrderMailer, type: :mailer do
  let(:work_order) { create(:work_order_with_jobs) }
  let(:work_order_mailer) { WorkOrderMailer.with(work_order: work_order) }

  describe "dispatch_failed" do
    let(:mail) { work_order_mailer.dispatch_failed }

    it 'has access to URL helpers' do
      expect { work_plan_dispatch_url(work_order.work_plan) }.not_to raise_error
    end

    it "renders the headers" do
      expect(mail.subject).to eq("(test) Dispatch failed for Work Order #{work_order.id}")
      expect(mail.to).to eq([work_order.work_plan.owner_email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match(work_plan_build_url(work_order.work_plan, :dispatch))
    end
  end

  describe "dispatched" do
    let(:mail) { work_order_mailer.dispatched }

    it "renders the headers" do
      expect(mail.subject).to eq("(test) Work Order #{work_order.id} has been dispatched")
      expect(mail.to).to eq([work_order.work_plan.owner_email])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match(work_plan_build_url(work_order.work_plan, :dispatch))
    end
  end

end
