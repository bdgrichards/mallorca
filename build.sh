#!/bin/bash
cd "$(dirname "$0")"
node -e "
const fs = require('fs');
const files = fs.readdirSync('data').filter(f => f.endsWith('.json')).sort((a,b) => parseInt(a) - parseInt(b));
const items = files.map(f => JSON.parse(fs.readFileSync('data/' + f, 'utf8')));
fs.writeFileSync('items.json', JSON.stringify(items));
console.log('Built items.json with ' + items.length + ' items from data/');
"
