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
        renderError('There was an error while accessing the Billing service');
      }
    });
  });
});


function renderError(msg) {
  var errorMsg = '<div class="alert-danger alert alert-dismissible" role="alert">'+msg+'</div>';
  $("#flash-display").html(errorMsg);
}


function renderDefaultProductDefinition(data) {

  setProductData(data);
  var updatedHTML = createElements();

  $('#product-definition').html(updatedHTML);
  $('#product-definition').show();

  // on change of a select option
  // get the element of the new selected
  // go through the building select elements setting the new element as the selected

  // $('#select0').change(function(){
  //   let newValue = $('#select0').val();
  //   let html = createElements(newValue);
  //   debugger
  //   updatedHTML = html + createSelect(availableLinks[newValue], newValue);

  //   $('#product-definition').html(updatedHTML);
  //   $('#product-definition').show();
  // });


  function createElements() {
    var selectHtml = '';
    for (let i = 0; i < defaultPath.length; ++i) {
      let defaultKey;
      i == 0 ? defaultKey = 'start' : defaultKey = defaultPath[i-1];
      selectHtml += createSelect(availableLinks[defaultKey], defaultPath[i], i);
    }
    return selectHtml;
  }

  function createSelect(options, defaultOption, selectNumber) {
    let selectString = `<select style="width:100px" id="select${selectNumber}">`;
    if (typeof(options) == 'string') {
      selectString += "<option>" + options + "</option>";
    } else {
      for (let i = 0; i < options.length; ++i) {
        if (defaultOption == options[i]) {
          selectString += "<option selected>" + options[i] + "</option>";
        } else {
          selectString += "<option>" + options[i] + "</option>";
        }
      }
    }
    selectString += '</select>';
    return selectString;
  }
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

function setProductData(data) {
  if (data.name == 'Cancer cell line banking test'){
    defaultPath = ['X','L','O'];
    availableLinks = {
      'start': ['A','X','B'],
      'A': 'end',
      'B': 'end',
      'O':'end',
      'L': ['O','end'],
      'X': ['L', 'O', 'end']
    }
  } else if (data.name == "CRISPR Guide RNA transduction"){
    defaultPath = ['D','C'];
    availableLinks = {
      'start': ['A','B','C','D'],
      'A': 'end',
      'B': 'end',
      'C':'end',
      'D': ['A','B','C'],
    }
  } else {
    defaultPath = ['id1','id4', 'id7'];
    availableLinks = {
      'start': ['id1','id3','id8'],
      'id7': 'end',
      'id5': 'end',
      'id4': ['id7','end'],
      'id1': ['id5','id4'],
    }
  }
}