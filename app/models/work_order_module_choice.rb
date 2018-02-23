class WorkOrderModuleChoice < ActiveRecord::Base
  belongs_to :work_order, required: true
  belongs_to :process_module, class_name: 'Aker::ProcessModule', foreign_key: 'aker_process_modules_id'
end
