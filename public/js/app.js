$(function() {
  $("#search").autocomplete({
    source: function(request, response) {
      $.ajax({
        url: '/course_search', // this should point to whatever route you're using
        dataType: 'json',
        data: {
          q: request.term // Send the search query parameter in the request
        },
        success: function( data ) {

          // The results dont come back in the format jquery ui expects
          // so we make a new array that holds objects in the format
          // that the autocomplete wants.
          var results = $.map(data, function(course, index) {
            return { id: course.code, label: course.code+": "+course.title, value: course.code};
          });

          response(results);
        }
      });
    }
  });
});
