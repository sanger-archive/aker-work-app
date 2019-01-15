# frozen_string_literal: true

# A ViewModel for the plan wizard product view
module ViewModels
  class WorkPlanProduct

    attr_reader :work_plan

    def initialize(args)
      @work_plan = args.fetch(:work_plan) # Must be decorated already
    end

    def form_enabled?
      work_plan.in_construction?
    end

    def number_of_samples
      work_plan.original_set_size
    end

    def work_plan_product_id
      work_plan.product_id
    end

    def current_catalogues_with_products
      current_catalogues.map { |catalogue| build_catalogue(catalogue) }.insert(0, ['', ['']])
    end

  private

    def current_catalogues
      Catalogue.includes(:products).where(current: true)
    end

    def build_catalogue(catalogue)
      [catalogue.pipeline, build_products(catalogue.products)]
    end

    def build_products(products)
      products.map { |product| build_product(product) }
    end

    def build_product(product)
      # include whether the product is not available i.e needs to be disabled, and initial blank option
      [product.name, product.id, { disabled: product.suspended? }]
    end

  end
end