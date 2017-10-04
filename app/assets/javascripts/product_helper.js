// Used to show the selected product and cost infomation in 'Select Product' step
$(document).on("turbolinks:load", function() {
  $('#product-select').change(function(event){
    var productId = $("#product-select").val();

    $.ajax({
      headers: {
          'Accept' : 'application/vnd.api+json',
          'Content-Type' : 'application/vnd.api+json'
      },
      url: Routes.product_path(productId),
      type: 'GET',
      success: function(data){
        renderProductInformation(data);
        renderCostInformation(data);
      }
    });
  });
});

function renderProductInformation(data) {
  const product = {
    cost_per_sample: convertToCurrency(data.cost_per_sample),
    requested_biomaterial_type: data.requested_biomaterial_type,
    product_version: data.product_version,
    tat: data.tat,
    description: data.description,
    availability: data.availability,
    product_class: data.product_class,
  };
  const result = JST['templates/product'](product);

  $('#product-information').html(result);
  $('#product-information').show();
}

function renderCostInformation(data) {
    const numOfSamples = $("#product-select").attr('num_of_samples');
    const costPerSample = data.cost_per_sample;
    const total = numOfSamples * costPerSample;

    const cost = {
      num_of_samples: numOfSamples,
      cost_per_sample: convertToCurrency(costPerSample),
      total: convertToCurrency(total)
    }
    const result = JST['templates/cost'](cost);

    $('#cost-information').html(result);
    $('#cost-information').show();
}

function convertToCurrency(input) {
  if (typeof(input)=='string') {
    input = parseInt(input)
  }
  return '£' + input.toFixed(2);
};