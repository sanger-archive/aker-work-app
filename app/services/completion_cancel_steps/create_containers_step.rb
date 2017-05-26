class CreateContainersStep
	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	# 1 - Create containers
	def up
		@containers = []
		unless @msg[:work_order][:containers].any?{|c| c.has_key?(:_id)}
    		@containers = [MatconClient::Container.create(@msg[:work_order][:containers].map{|c| c.merge({print_count: 0})})].flatten
    	end
	end

	def down
		@containers.each do |c|
			MatconClient::Container.destroy(c.id)
		end
	end
end