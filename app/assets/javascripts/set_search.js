// Stores the names of all returned sets. Used later to prevent duplicates
var setResults = (function () {
  var setArray = []
  return setArray
})();

function setSearch() {
  var setName = document.getElementById("set-name").value;
  setName = setName.trim();

  // Set has been search previously, so don't bother searching again
  if (setResults.includes(setName.toLowerCase())) {
    return;
  }

  var url = `${setServiceURL}/sets?filter[name]=` + setName;

  $.get( url, function( response ) {
    if (response.data[0] === undefined) {
      // Set doesn't exist or service is down
      if (setName.length > 0) {
        $("#set-result").css("color", "red");
        $("#set-result").text("Set not found");
      } else {
        $("#set-result").text('');
      }
    } else {
      setResults.push(setName.toLowerCase());
      // Get set metadata from response
      var setID = response.data[0].id;
      var setSize = response.data[0].meta.size;
      var setCreationDate = response.data[0].attributes.created_at;

      // Add a row to the table for the returned set
      $('#set-list-table tbody').prepend(`<tr>
        <td>
          <div class="radio">
            <label for="work_order_original_set_uuid_${setID}">
              <input checked type="radio" value="${setID}" name="work_order[original_set_uuid]" id="work_order_original_set_uuid_${setID}"">
            </label>
          </div>
        </td>
        <td>${setName}</td>
        <td>${setSize} ${setSize > 1 ? "Samples" : "Sample"}</td>
        <td>${timeSince(setCreationDate)} ago</td>
        </tr>`);

      // Clear the set-result message text
      $("#set-result").text('');
    }
  });
}

// Roughly emulates Rails time_ago_in_words
function timeSince(date) {
  var timeSince = Math.floor((new Date() - new Date(date)) / 1000);

  if (timeSince >= 31557600) {
    return `${Math.round(timeSince / 31557600)} years`
  } else if (timeSince >= 2592000) {
    return `${Math.round(timeSince / 2592000)} months`
  } else if (timeSince >= 86400) {
    return `${Math.round(timeSince / 86400)} days`
  } else if (timeSince >= 3600) {
    return `${Math.round(timeSince / 3600)} hours`
  } else if (timeSince >= 60) {
    return `${Math.round(timeSince / 60)} minutes`
  } else {
    return `${Math.floor(timeSince)} seconds`
  }
}
