$(document).on('turbolinks:load', function() {

  $("a[data-behavior~='revise_set']").on('click', function(event) {
    // Don't follow the link
    event.preventDefault();

    // Show a nice little spinner
    var $spinner = $('<i class="fa fa-spinner fa-spin fa-fw"></i>');
    $(event.currentTarget).replaceWith($spinner);

    $.ajax({
      dataType: 'html',
      type: 'POST',
      url: event.currentTarget.href
    })

    // When successful...
    .then(
      function(result) {
        var html = $.parseHTML(result);
        $spinner.replaceWith(html); // Show the link returned from the server
        html[0].click(); // Click the link to the Revised Set
      },

      // When unsuccessful...
      function(result) {
        $spinner.replaceWith('<span class="label label-danger">Failed to Revise Set</span>');
      }
    )

  });

})