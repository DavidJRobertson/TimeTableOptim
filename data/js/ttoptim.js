//#! /usr/bin/env node

fs = require('fs');
csp = require('./csp/index.js');

Date.prototype.getDOY = function() {
  var epoch = new Date('2015-01-01');

  var diffms   = this - epoch;
  var diffdays = Math.ceil(diffms / (1000*60*60*24))

  return diffdays;
};


var file = fs.readFileSync('./data/djr.json');
var courses = JSON.parse(file);

function generateAllTimesList(section) {
  var days = {'Mo': 1, 'Tu': 2, 'We': 3, 'Th': 4, 'Fr': 5, 'Sa': 6, 'Su': 7};
  var optimes = [];


  for (var periodid in section.dates) {
    var period = section.dates[periodid];

    var a = period.period.split(' - ');
    var startday = new Date(a[0].split('/').reverse().join('-'));
    var endday   = new Date(a[1].split('/').reverse().join('-'));

    var daycode   = days[period.times.substring(0, 2)];
    var starttime = parseInt(period.times.substring(4, 6), 10);
    var endtime   = parseInt(period.times.substring(12, 14), 10);

    var tl = [];
    for (var tx = starttime; tx < endtime; tx++) {
      tl.push(tx);
    }

    var enddoy = endday.getDOY();
    var doy = startday.getDOY();
    if (startday.getDay() != daycode) {
      var diff = daycode - startday.getDay();
      if (diff < 1) {
        diff = diff + 7;
      }
      doy = doy + diff;
    }

    while (doy <= enddoy) {
      for (var t in tl) {
        optimes.push(doy.toString()+':'+tl[t].toString());
      }
      doy = doy + 7;
    }
  }

  return optimes;
}




var p = csp.DiscreteProblem();
var sectioncatalogue = {};


for (var i=0; i<courses.length; i++) {
  var course = courses[i];
  var groups = {}
  for (var j=0; j<course.sections.length; j++){
    var section = course.sections[j];
    if (section.type === "Admin") { continue; }
    if (groups[section.type] === undefined) {
      groups[section.type] = [];
    }
    groups[section.type].push(section.id);
    section.course = course.code;
    section.alltimes = generateAllTimesList(section);
    sectioncatalogue[section.id] = section;

  }

  for (var groupkey in groups) {
    if (groups.hasOwnProperty(groupkey)) {
      group = groups[groupkey];
      p.addVariable(course.code+': '+groupkey, group);
    }
  }
}

function sectionsCompatible(secid1, secid2) {
  var sec1 = sectioncatalogue[secid1];
  var sec2 = sectioncatalogue[secid2];



  for (var t1i in sec1.alltimes) {
    var t1 = sec1.alltimes[t1i];
    for (var t2i in sec2.alltimes) {
      var t2 = sec2.alltimes[t2i];
      if (t1 == t2) {

        return false;
      }
    }
  }

  return true;
}


function sci(sec1, sec2) {
  for (var t1i in sec1.alltimes) {
    var t1 = sec1.alltimes[t1i];
    for (var t2i in sec2.alltimes) {
      var t2 = sec2.alltimes[t2i];
      if (t1 == t2) {

        return false;
      }
    }
  }

  return true;
}

function sectionsCompatible1(secid1, secid2) {
  var sec1 = sectioncatalogue[secid1];
  var sec2 = sectioncatalogue[secid2];


}

for (var va in p.variables) {
  for (var vb in p.variables) {
    if (va !== vb) {
      p.addConstraint([va, vb], sectionsCompatible);
    }
  }
}

console.log("SOLUTION: \n");
var solution = p.getSolution()
for (var c in solution) {
  var sec = sectioncatalogue[solution[c]];
  console.log(c + "    -    " + sec.name);
}
