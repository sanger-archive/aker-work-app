class CreateContainersStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 1 - Create containers
	def up
		unless @msg[:work_order][:containers].any?{|c| c.has_key?(:_id)}
    		MatconClient::Container.create(@msg[:work_order][:containers])
    	end
	end

	def down
	end
end