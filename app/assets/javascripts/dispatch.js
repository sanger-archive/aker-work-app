
function postCreateEditableSet(workOrderId, url) {
  // Need to open the new window here because if we try and open
  // it later, it will be popup-blocked.
  var newTab = window.open('about:blank', '_blank');
  $.post(url, function(data) {
    if (data.error) {
      alert("Error "+data.error);
    } else {
      updateSetsOnScreen(workOrderId, data.new_set_name, data.view_set_url, newTab);
    }
  });
}

function updateSetsOnScreen(workOrderId, newSetName, viewSetUrl, newTab) {
  var originalSetElement = $('#original-set-for-'+workOrderId);
  var setElement = $('#set-for-'+workOrderId);
  var originalSetLink = setElement.html();
  originalSetLink = originalSetLink.substring(originalSetLink.indexOf("<a"), originalSetLink.indexOf("</a>")+4);

  setElement.html('Input Set: <a target="_blank" href="'+viewSetUrl+'">'+newSetName+'</a>');
  originalSetElement.html('Based on original set: '+originalSetLink);

  newTab.location.href = viewSetUrl;
}
