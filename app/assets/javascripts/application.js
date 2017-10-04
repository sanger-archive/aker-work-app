// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require bootstrap-sprockets
//= require js-routes
//= require_tree ./templates
//= require_tree .

$(document).on("turbolinks:load", function() {
  $("[data-behavior~=datepicker]").each(function() {
    $(this).datepicker({
      dateFormat: 'yy-mm-dd',
      minDate: '+0d'
    });
  });

  // Used when selecting a set (create work order step 1) to allow a radio button
  // to be checked by clicking the row, instead of just the radio button
  $('#set-list-table tr').click(function (event) {
    if (event.target.type !== 'radio') {
      $(':radio', this).prop("checked", true);
    }
  })

  // Used to show the selected product and cost infomation in 'Select Product' step
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
      num_of_samples: convertToCurrency(numOfSamples),
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