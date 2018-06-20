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
//= require set_search
//= require dispatch
//= require_tree .

$(document).on("turbolinks:load", function() {
  $("[data-behavior~=datepicker]").each(function() {
    $(this).datepicker({
      dateFormat: 'yy-mm-dd',
      minDate: '+0d'
    });
  });

  // Used when selecting a set (create work order step 1) to allow a radio button
  // to be checked by clicking the row, instead of just the radio button.
  // Also used on the "Select Data Release" step
  $('.radio-table tr').click(function (event) {
    if (event.target.type !== 'radio') {
      $(':radio', this).prop("checked", true);
    }
  })
});
