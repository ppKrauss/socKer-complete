/**
 * Convert vCard fake files to JSON files.
 * Need previous         #npm install vcard-json
 * Use at project's root #nodejs src/build3-contacts.js data/contacts-fake1.vcf > data/contacts-fake1.json
 */
var vcard = require('vcard-json');

if (!process.argv[2]) {
	console.log("\nERROR: please add vcf filepath as parameter");
	process.exit();
}

vcard.parseVcardFile( process.argv[2], function(err, data){
  if(err) console.log("\nERROR: "+ err);
  else {
    console.log( JSON.stringify(data) );    
  }
});

