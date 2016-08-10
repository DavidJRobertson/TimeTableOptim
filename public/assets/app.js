$(function() {
  var weekNumber = 1;
  var solution = {};

  function split(val) {
    return val.split(/,\s*/);
  }
  function extractLast(term) {
    return split(term).pop();
  }
  function addDays(date, days) {
    var result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  function extractCoursesFromInput() {
    var ar = split($("#spa-search")[0].value);
    if (ar[ar.length-1] == "") {
      ar.pop();
    }
    return ar;
  }

  function getSolutionData(courses, success_callback, failure_callback) {
    $.ajax({
      url: '/solve',
      method: 'POST',
      dataType: 'json',
      data: { courses: courses },
      success: function(data) {
        solution = data;
        success_callback(data);
      },
      error: function(data) {
        console.log(data);
        if (failure_callback) {
          failure_callback(data);
        }
      }
    });
  }

  function updateTimetable(data, weekCode) {
    // clear out the timetable entirely
    $(".tt-cell").html("");
    $(".tt-cell").removeClass("tt-event");

    // now insert the new data
    var weekStart = (weekCode-1)*7;
    var weekEnd   = weekStart + 6;

    var weekIndex = new Date(data["start_dates"]["semester_1"] + "T13:00:00");
    var weekStartDate = addDays(weekIndex, weekStart);

    $("#tt-week-code").html(weekCode);
    $("#tt-week-start").html(weekStartDate.toISOString().slice(0, 10));

    var weekEvents = [
      // 9   10   11   12   13   14   15   16   17
      [null, null, null, null, null, null, null, null, null], // Mon
      [null, null, null, null, null, null, null, null, null], // Tue
      [null, null, null, null, null, null, null, null, null], // Wed
      [null, null, null, null, null, null, null, null, null], // Thu
      [null, null, null, null, null, null, null, null, null]  // Fri
    ]


    var courses  = data["courses"];
    var sections = data["sections"];
    $.each(sections, function(sectionIndex, section) {
      $.each(section["dates"], function(dateIndex, secDate) {
        var d = secDate[0];
        if (d >= weekStart && d < weekEnd) {
          var day  = d - weekStart; // day of week
          var time = secDate[1];
          var val = {"course": section["course"], "section": section["name"], "type": section["type"]};
          weekEvents[day][time-9] = val;
          // todo: join long sections together
        }
      });
    });

    $.each(weekEvents, function(day, dayEvents) {
      $.each(dayEvents, function(i, event) {
        var hour = i + 9;
        if (event != null) {
          var cell = $(".tt-cell[data-day="+day+"][data-hour="+hour+"]");
          cell.html(event["course"]+": "+event["section"]+" ("+event["type"]+") <br />"+courses[event["course"]]);
          cell.addClass("tt-event");
        }
      });
    });
  }

  $(".tt-jump").click(function(e) {
    e.preventDefault();
  });
  $("#tt-jump-prev").click(function() {
    weekNumber = weekNumber - 1;
    updateTimetable(solution, weekNumber);
  })
  $("#tt-jump-next").click(function() {
    weekNumber = weekNumber + 1;
    updateTimetable(solution, weekNumber);
  })
  $("#tt-jump-sem1").click(function() {
    weekNumber = 1;
    updateTimetable(solution, weekNumber);
  })
  $("#tt-jump-sem2").click(function() {
    weekNumber = 17; // XXX: calculate this value from data sent by server
    updateTimetable(solution, weekNumber);
  })


  $(".tt-cell").click(function(e) {
    console.log(e.target);
  });

  function spaCoursesUpdated(courses) {
    getSolutionData(extractCoursesFromInput(), function(data) {
      // Success

      console.log(data);

      // Course choices list
      $("#solution-printout").html(data["printout"]);

      // Timetable
      weekNumber = 1;
      updateTimetable(data, weekNumber);

      $("#solution-pane").show();
      $("#no-solution-pane").hide();
      $("#error-pane").hide();
    }, function(data) {
      // Failure
      $("#error-message").text(data.responseJSON["error"]["message"]);
      $("#solution-pane").hide();
      $("#no-solution-pane").hide();
      $("#error-pane").show();
    });
  }

  $("#spa-search").on( "keydown", function( event ) {
    // don't navigate away from the field on tab when selecting an item
    if ( event.keyCode === $.ui.keyCode.TAB && $( this ).autocomplete( "instance" ).menu.active ) {
      event.preventDefault();
    }
  }).autocomplete({
    source: function(request, response) {
      $.ajax({
        url: '/course_search',
        dataType: 'json',
        data: { q: extractLast(request.term) },
        success: function(data) {
          var results = $.map(data, function(course, index) {
            return { id: course.code, label: course.code + ": " + course.title, value: course.code};
          });
          response(results);
        }
      });
    },
    search: function() {
      // custom minLength
      var term = extractLast( this.value );
      if ( term.length < 2 ) {
        return false;
      }
    },
    focus: function() {
      // prevent value insertion on focus
      return false;
    },
    select: function( event, ui ) {
      var terms = split( this.value );
      // remove the current input
      terms.pop();
      // add the selected item
      terms.push( ui.item.value );
      // add placeholder to get the comma-and-space at the end
      terms.push( "" );
      this.value = terms.join( ", " );

      spaCoursesUpdated();

      return false;
    }
  }).change(function() {
    // make sure not to miss manual changes
    spaCoursesUpdated();
  });





});
