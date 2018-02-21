class WorkOrderModuleChoice < ActiveRecord::Base
  belongs_to :work_order, required: true
end
