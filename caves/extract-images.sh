#!/bin/bash
cd "$(dirname "$0")"
BASE="http://www.mallorcaverde.es"

for f in data/*.json; do
  url=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$f','utf8')).url||'')")
  if [ -z "$url" ]; then continue; fi

  photo_url=$(echo "$url" | sed 's/\.htm$/-1.htm/')
  
  imgs=$(curl -s --max-time 5 "$photo_url" | grep -o "imageURLs:\[.*\]" | head -1 | \
    sed "s/imageURLs:\[//;s/\].*//;s/'//g" | tr ',' '\n' | sort -u | \
    while read img; do
      if [ -n "$img" ]; then
        echo "${BASE}/${img}"
      fi
    done | paste -sd',' -)

  if [ -n "$imgs" ]; then
    fname=$(basename "$f")
    echo "$fname: $imgs"
    
    node -e "
      const fs = require('fs');
      const data = JSON.parse(fs.readFileSync('$f', 'utf8'));
      data.images = '${imgs}'.split(',').filter(Boolean);
      fs.writeFileSync('$f', JSON.stringify(data, null, 2));
    "
  fi
done

echo "Done extracting images."
