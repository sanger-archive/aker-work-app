
function setSearch() {
  var setName = document.getElementById("set-name").value;
  setName = setName.trim();

  var url = relativeRoot + 'sets/' + setName;

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
      // Get set metadata from response
      var setNameCaseMatched = response.data[0].attributes.name;
      var setID = response.data[0].id;
      var setSize = response.data[0].meta.size;
      var setCreationDate = response.data[0].attributes.created_at;

      // Set is already present in the list, so select it for the user
      if (setNames.includes(setName.toLowerCase())) {
        $("#set-result").css("color", "orange");
        $("#set-result").text("Set already in list. It's been selected for you");
        $("input[name=work_order\\[original_set_uuid\\]][value=" + setID + "]").prop('checked', true);
        return;
      }

      // Set is empty, throw an error
      if (setSize == 0) {
        $("#set-result").css("color", "orange");
        $("#set-result").text("Set is empty");
        return;
      }

      setNames.push(setName.toLowerCase());

      // Add a row to the table for the returned set
      $('#set-list-table tbody').prepend(`<tr>
        <td>
          <div class="radio">
            <label for="work_order_original_set_uuid_${setID}">
              <input checked type="radio" value="${setID}" name="work_order[original_set_uuid]" id="work_order_original_set_uuid_${setID}"">
            </label>
          </div>
        </td>
        <td>${setNameCaseMatched}</td>
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
