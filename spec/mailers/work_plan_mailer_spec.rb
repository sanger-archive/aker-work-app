require 'rails_helper'

RSpec.describe WorkPlanMailer, type: :mailer do
  describe 'work plan ready' do
    let(:work_plan) { create(:work_plan) }
    let(:mail) { described_class.message_plan_updated(work_plan).deliver_now }

    it 'renders the subject' do
      expect(mail.to).to eq(['akerdev@sanger.ac.uk'])
      expect(mail.subject).to eq("Work Plan #{work_plan.id} updated")
    end
  end
end