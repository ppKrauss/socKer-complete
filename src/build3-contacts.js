/**
 * Convert vCard fake files to JSON files.
FALTA remover excessos e ficar com o basico no tel, adr e email.
tel[0].pref, tel[0].value, etc.
ORG é sempre "Organization":{name:value}
 * Need previous         #npm install vcard-json
 * Use at project's root #nodejs src/build3-contacts.js data/contacts-fake1.vcf > data/contacts-fake1.json
 */
var fs = require ('fs');   // file system call
var s = require('underscore.string');  // see s(*)
var _ = require ('underscore');        // see _.*

function addKey(obj,key,data, objItem=false) {
  if (objItem && typeof data !== 'object') data = {'value':data};
  if (['email','tel','adr','label'].indexOf(key) != -1) {
    if (data && data.value) {
      if (data.meta && data.meta.TYPE) {
        data.type = data.meta.TYPE.toLowerCase().trim().split(',');
      }
      delete data.meta;
      if (key!='adr')
        data.value = (data.value.constructor===Array)? data.value[0]: data.value;
      else { // adr
        if (data.value && data.value.constructor===Array && data.value.length==7) {
          [data.pobox,data.ext,data.streetAddress,data.city,data.state,data.postalCode,data.addressCountry]=data.value;
          delete data.value;
        } else
          data.WARNING = 'ADR must by a Array with length=7';
      }
    } // end:data and tel or adr
    if (obj[key]) { // is to add
      if (obj[key].constructor !== Array) console.log("\nERROR: key "+key+" must be Array\n");
      obj[key].push(data);
    } else { // is new
      obj[key] = [data];
    }
  } else // must be a value
    obj[key] = data;
}

function parseVCard(inputBlockLines) {
  // SIMPLIFICAR (basta indicar o preferido em caso de multiplos emails, telefones ou endereços) [{a},{b,pref:true},{c}]
		// Step2 parse fields	directly, with no special case.
    var Re1 = /^(version|fn|title|org|n|nickname|geo|categories|class|label|profile|email|adr|note|url):(.+)$/i;
    var Re2 = /^([^:;]+)((?:;[^:;]+)+):(.+)$/; // fieldName;fieldOptions:fieldValue
    var ReKey = /item\d{1,2}\./; // agrupador, ver como usar em hierarquia ou array.
    var fields = {};
    var discard = [];
    inputBlockLines.forEach(function (line) {
        var results, key;
        if (Re1.test(line)) {
            results = line.match(Re1);
            key = results[1].toLowerCase();
            addKey( fields, key, vc_unescape(results[2]), false );
        } else if (Re2.test(line)) {
            results = line.match(Re2);
            key = results[1].replace(ReKey, '').toLowerCase(); // fieldName
            if (!fields[key]) fields[key] = [];
            addKey(
              fields,
              key,
              {
                  meta:  vc_splitSCparts(results[2]),
                  value: vc_unescape(results[3]).split(';')
              },
              true );
            //fields[key].push()
        } else discard.push(line);
    });

    if (fields['n']) {
      fields = obj_addByKeysVals(
       fields,
       ['familyName','givenName','additionalName','honorificPrefix','honorificSuffix'],
       fields['n'].split(';'),
       false // nao copia vazios.
      );
      delete fields['n'];
    }

    _.omit( fields, _.isEmpty) // similar to _.compact()
    discard = _.without(discard,'','BEGIN:VCARD','END:VCARD')
    if (discard.length>0)
  	  fields['warning-DISCARD'] = discard;
  return fields;
};


if (!process.argv[2]) {
	console.log("\nERROR: please add vcf filepath as parameter");
	process.exit();
} else {
  var r = [];
	var text = fs.readFileSync(process.argv[2],'utf-8')
	for (b of vc_parseBlocks(text) ) {
		var vc = vc_parseBlock(b,false)
    r.push(vc)
	}
  console.log( JSON.stringify(r,null,3) );
}

///
// vc_* UTILS

function vc_parseBlocks(data) { // not work for AGENT into a vCard
  var dataStr = data.toString("utf-8");
	var blocks = [];
	for (vcblock of dataStr.split(/(^|\r\n|\r|\n)BEGIN:VCARD\s/)  ) {
			var tmp = vcblock.trim();
	    if (tmp) blocks.push( "BEGIN:VCARD\n"+tmp );
	}
	return blocks;
}

function vc_parseBlock(data,parseVcard=false) {
	// Step1 redo data normalizing lines
	var lines = s(data).lines();
	var linesFull = [''];
	var item = 0;
	var buf = '';
	for (line of lines)
	 	if (line.charAt(0)==' ')
			buf += line.substr(1);
		else {
			linesFull[item] += buf;
			item ++;
			linesFull[item] = line;
			buf = '';
		}
  // return linesFull.join("\n");
	return parseVCard? parseVCard(linesFull): linesFull.join("\n");
}
function vc_unescape(x) {
	return x.replace(/\\,/g, ",").replace(/\\n/g, "\n");
}

function vc_splitSCparts(r) {
  var meta = {};
  r.split(';')
    .map(function (p, i) {
      var match = p.match(/([a-z]+)=(.*)/i);
      if (match) {
          return [match[1], vc_unescape(match[2])];
      } else {
          return ["TYPE" + (i === 0 ? "" : i), p];
      }
    })
    .forEach(function (p) {
      meta[p[0]] = vc_unescape(p[1]);
    });
  return meta;
}

// JS LIB
//// complement for underscore.js

function obj_addByKeysVals(obj,keys,vals,canEmpty=false) {
  for (var i=0; i<vals.length;i++) {
    var val = vals[i];
    var key = keys[i];
    if (canEmpty||val) obj[key] = val;
  }
  return obj;
}
