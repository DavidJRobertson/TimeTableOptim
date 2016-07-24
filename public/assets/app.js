$(function() {

  $("#search").autocomplete({
    source: function(request, response) {
      $.ajax({
        url: '/course_search',
        dataType: 'json',
        data: { q: request.term },
        success: function(data) {
          var results = $.map(data, function(course, index) {
            return { id: course.code, label: course.code+": "+course.title, value: course.code};
          });
          response(results);
        }
      });
    }
  });


  /* SINGLE PAGE APP */

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

  function transposeArray(array) {
    return array[0].map(function(col, i) {
      return array.map(function(row) {
        return row[i]
      })
    });
  }

  function extractCoursesFromInput() {
    var ar = split($("#spa-search")[0].value);
    if (ar[ar.length-1] == "") {
      ar.pop();
    }
    return ar;
  }

  function getSolutionData(courses, callback) {
    $.ajax({
      url: '/solve',
      method: 'POST',
      dataType: 'json',
      data: { courses: courses },
      success: function(data) {
        callback(data);
      }
    });
  }

  function spaCoursesUpdated(courses) {
    console.log("spaCoursesUpdated", extractCoursesFromInput());

    getSolutionData(extractCoursesFromInput(), function(data) {
      console.log(data);

      // Course choices list
      $("#solution-printout").html(data["printout"]);

      // Timetable
      var weekCode = 1; // XXX allow this to be altered.
      var weekIndex = new Date(data["start_dates"]["semester_1"]);
      var weekStart = addDays(weekIndex, ((weekCode-1)*7));
      var weekEnd = addDays(weekStart, 7);

      var weekEvents = [
        // 9   10   11   12   13   14   15   16   17
        [null, null, null, null, null, null, null, null, null], // Mon
        [null, null, null, null, null, null, null, null, null], // Tue
        [null, null, null, null, null, null, null, null, null], // Wed
        [null, null, null, null, null, null, null, null, null], // Thu
        [null, null, null, null, null, null, null, null, null]  // Fri
      ]

      var sections = data["sections"];
      $.each(sections, function(sectionIndex, section) {
        $.each(section["dates"], function(dateIndex, secDate) {
          var d = new Date(secDate[0]);
          if (d >= weekStart && d < weekEnd) {
            var day  = (d - weekStart)/(1000*60*60*24); // day of week
            var time = secDate[1];
            var val = {"course": section["course"], "section": section["name"]};
            weekEvents[day][time-9] = val;
            // todo: join long sections together
          }
        });
      });

      //var transposedWeekEvents = transposeArray(weekEvents);
      $.each(weekEvents, function(day, dayEvents) {
        console.log(dayEvents);
        $.each(dayEvents, function(i, event) {
          var hour = i + 9;
          if (event != null) {
            var cell = $(".tt-cell[data-day="+day+"][data-hour="+hour+"]");
            cell.html(event["course"]+": "+event["section"]);
            cell.addClass("tt-event");
          }
        });
      });

      /*
        @solution.each do |classec, section|

          section.dates.each do |secdate|
            if secdate[0] >= @weekstart and secdate[0] < @weekstart+7
              day = (secdate[0] - @weekstart).to_i
              time = secdate[1]-9
              val = [classec[0], section.name]
              @weekevents[day][time] = val.dup
              @weekevents[day][time] << 1


              prev = @weekevents[day][time-1]
              if prev and prev[0..1] == val
                @weekevents[day][time] << :continued

                l = 1
                while @weekevents[day][time-l] and @weekevents[day][time-l][0..1] == val
                  l += 1
                end
                @weekevents[day][time-l+1][2] = l
              end

            end

          end
        end
      */













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
