// Used to show the selected product and cost infomation in 'Select Product' step
$(document).on("turbolinks:load", function() {

  $.ajaxSetup({
    headers: {
      'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
    }
  });

  $('#product-select').change(function(event){
    var productId = $("#product-select").val();
    var workOrderId = $("#work-order-id").val();

    $.ajax({
      url: '/api/v1/work_orders/'+workOrderId+'/products/'+productId,
      method: 'GET',
      dataType: 'json',
      contentType: 'application/json',
      success: function(data){
        renderProductInformation(data);
        renderCostInformation(data);
      },
      error: function() {
        renderError('There was an error while accessing the Billing service');
      }
    });
  });
});

function renderError(msg) {
  let errorMsg = '<div class="alert-danger alert alert-dismissible" role="alert">'+msg+'</div>';
  $("#flash-display").html(errorMsg);
}

function renderProductInformation(data) {
  const product = {
    cost_per_sample: convertToCurrency(data.unit_price),
    requested_biomaterial_type: data.requested_biomaterial_type,
    product_version: data.product_version,
    tat: data.TAT,
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
    const costPerSample = data.unit_price;
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