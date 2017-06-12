class Catalogue < ApplicationRecord

  has_many :products

  def self.create_with_products(catalogue_params)
  	catalogue = nil
  	transaction do
  		lims_id = catalogue_params[:lims_id]
  		where(lims_id: lims_id).update_all(current: false)
  		catalogue = create!(catalogue_params.reject { |k,v| (k=='products') }.merge({current: true}))
  		catalogue_id = catalogue.id
  		product_params = catalogue_params['products']
      price_placeholder = 0
  		product_params.each do |pp|
        pp[:product_class] = Product.human_product_class_to_symbol(pp[:product_class] )
  			Product.create!(pp.merge({ catalogue_id: catalogue_id, cost_per_sample: price_placeholder}))
  		end
  	end
  	catalogue
  end
end
