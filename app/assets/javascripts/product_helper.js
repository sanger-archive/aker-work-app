(function($, undefined) {
// Used to show the selected product and cost infomation in 'Select Product' step

  function ProductSelector(node, params) {
    this.node = (node || $('#product-select'));
    this.params = params;

    this.productInformationSelector = (params.productInformationSelector || '#product-information');
    this.costInformationSelector = (params.costInformationSelector || '#cost-information');

    this.attachHandlers();
  }

  var proto = ProductSelector.prototype;

  proto.attachHandlers = function() {
    $(this.node).change($.proxy(this.onChangeSelector, this));
  }

  proto.onChangeSelector = function(event){

    var productId = $(this.node).val();
    $.ajax({
      headers: {
          'Accept' : 'application/vnd.api+json',
          'Content-Type' : 'application/vnd.api+json'
      },
      url: Routes.product_path(productId),
      type: 'GET',
      success: $.proxy(this.onReceiveProduct, this)
    });
  }

  proto.onReceiveProduct = function(data) {
    this.renderProductInformation(data);
    this.renderCostInformation(data);
  };

  proto.renderProductInformation = function(data) {
    const product = {
      cost_per_sample: this.convertToCurrency(data.cost_per_sample),
      requested_biomaterial_type: data.requested_biomaterial_type,
      product_version: data.product_version,
      tat: data.TAT,
      description: data.description,
      availability: data.availability,
      product_class: data.product_class,
    };
    const result = JST['templates/product'](product);

    $(this.productInformationSelector).html(result);
    $(this.productInformationSelector).show();
  }

  proto.renderCostInformation = function(data) {
      const numOfSamples = $(this.node).attr('num_of_samples');
      const costPerSample = data.cost_per_sample;
      const total = numOfSamples * costPerSample;

      const cost = {
        num_of_samples: numOfSamples,
        cost_per_sample: this.convertToCurrency(costPerSample),
        total: this.convertToCurrency(total)
      }
      const result = JST['templates/cost'](cost);

      $(this.costInformationSelector).html(result);
      $(this.costInformationSelector).show();
  }

  proto.convertToCurrency = function(input) {
    if (typeof(input)=='string') {
      input = parseInt(input)
    }
    return '£' + input.toFixed(2);
  };

  var INSTANCE = null;

  function onPageLoad() {
    if (INSTANCE!=null) {
      return;
    }
    INSTANCE = new ProductSelector($('#product-select'), {
      productInformationSelector: '#product-information',
      costInformationSelector: '#cost-information'
    });
  }

  $(document).on("turbolinks:load", onPageLoad);
  $(document).ready(onPageLoad);
})(jQuery)
