#!/bin/bash
cd "$(dirname "$0")"
node -e "
const fs = require('fs');
const files = fs.readdirSync('data').filter(f => f.endsWith('.json')).sort();
const items = files.map(f => JSON.parse(fs.readFileSync('data/' + f, 'utf8')));
fs.writeFileSync('caves.json', JSON.stringify(items));
console.log('Built caves.json with ' + items.length + ' caves from data/');
"
