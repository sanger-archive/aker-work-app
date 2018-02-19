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
      url: Routes.root_path()+'api/v1/work_orders/'+workOrderId+'/products/'+productId,
      method: 'GET',
      dataType: 'json',
      contentType: 'application/json',
      success: function(data){
        renderProductInformation(data);
        renderCostInformation(data);
        renderDefaultProductDefinition(data);
      },
      error: function() {
        hideProductInfo();
        renderError('There was an error while accessing the Billing service');
      }
    });
  });
});

function hideProductInfo() {
  $("#product-select-description").hide();
  $("#product-information").hide();
  $("#cost-information").hide();
}

function renderError(msg) {
  var errorMsg = '<div class="alert-danger alert alert-dismissible" role="alert">'+msg+'</div>';
  $("#flash-display").html(errorMsg);
}

function renderProductInformation(data) {
  var product = {
    cost_per_sample: convertToCurrency(data.unit_price),
    requested_biomaterial_type: data.requested_biomaterial_type,
    product_version: data.product_version,
    tat: data.TAT,
    description: data.description,
    availability: data.availability,
    product_class: data.product_class,
  };
  var result = JST['templates/product'](product);

  $('#product-information').html(result);
  $('#product-information').show();
}

function renderCostInformation(data) {
    var numOfSamples = $("#product-select").attr('num_of_samples');
    var costPerSample = data.unit_price;
    var total = numOfSamples * costPerSample;

    var cost = {
      num_of_samples: numOfSamples,
      cost_per_sample: convertToCurrency(costPerSample),
      total: convertToCurrency(total)
    }
    var result = JST['templates/cost'](cost);

    $('#cost-information').html(result);
    $('#cost-information').show();
}

function convertToCurrency(input) {
  if (typeof(input)=='string') {
    input = parseInt(input)
  }
  return '£' + input.toFixed(2);
};

function renderDefaultProductDefinition(data) {
  var productData = getProductData(data.id).then( function(response) {
    var availableLinks = response.data.available_links;
    var defaultPath = response.data.default_path;
    ReactDOM.render(
      React.createElement(ProductDescription, {availableLinks: availableLinks, defaultPath: defaultPath}, null),
      document.getElementById('product-select-description')
    );
  });
  $("#product-select-description").show();
}

function getProductData(product_id) {
  var url = relativeRoot + '/products/' + product_id;

  return $.get( url, function( response ) {
    if (response.data === undefined) {
      // Product doesn't exist or service is down
    } else {
      defaultPath = response.data.default_path;
      availableLinks = response.data.available_links;
    }
    return { defaultPath: defaultPath, availableLinks: availableLinks };
  });
}