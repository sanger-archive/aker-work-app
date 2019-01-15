$(document).on("turbolinks:load", function() {
  $("[data-behavior~=select_all]").each(function() {
    var $el = $(this);

    // On change select/deselect all inputs in the form
    $el.on('change', function(e) {
      var $checkboxes = $el.closest('form').find(':checkbox');
      $checkboxes.prop('checked', $el.is(':checked'))
    });
  });
});