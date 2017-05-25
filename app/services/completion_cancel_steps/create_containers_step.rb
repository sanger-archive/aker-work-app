class CreateContainersStep
	attr_reader :containers

	def initialize(work_order, msg)
		@work_order = work_order
		@msg = msg
	end

	def containers_to_create
		@msg[:work_order][:containers].reject do |c| 
				c.has_key?(:_id)
		end.map do |c| 
			c.merge({print_count: 0})
		end
	end

	# 1 - Create containers
	def up
		@containers = []
		unless @msg[:work_order][:containers].empty?
			elements = containers_to_create

			unless elements.empty?
	    	@containers = [MatconClient::Container.create(elements)].flatten
	    end
	  end
	end

	def down
		@containers.each do |c|
			MatconClient::Container.destroy(c.id)
		end
	end
end