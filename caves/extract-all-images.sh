#!/bin/bash
cd "$(dirname "$0")"
BASE="http://www.mallorcaverde.es"

for f in data/*.json; do
  url=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$f','utf8')).url||'')")
  if [ -z "$url" ]; then continue; fi

  all_imgs=""

  # Method 1: Check main cave page for inline <img> tags
  inline=$(curl -s --max-time 8 "$url" | grep -oi 'src="imagenes/espeleo/[^"]*"' | \
    sed 's/src="//;s/"$//' | sort -u | \
    while read img; do
      echo "${BASE}/${img}"
    done | paste -sd',' -)

  # Method 2: Check -1.htm photo subpage for Flash viewer imageURLs
  photo_url=$(echo "$url" | sed 's/\.htm$/-1.htm/')
  flash=$(curl -s --max-time 8 "$photo_url" 2>/dev/null | grep -o "imageURLs:\[.*\]" | head -1 | \
    sed "s/imageURLs:\[//;s/\].*//;s/'//g" | tr ',' '\n' | sort -u | \
    while read img; do
      if [ -n "$img" ]; then
        echo "${BASE}/${img}"
      fi
    done | paste -sd',' -)

  # Method 3: For URLs with spaces/special chars, try URL-decoded photo page
  decoded_url=$(echo "$url" | python3 -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null)
  if [ "$decoded_url" != "$url" ]; then
    photo_url2=$(echo "$decoded_url" | sed 's/\.htm$/-1.htm/')
    flash2=$(curl -s --max-time 8 "$photo_url2" 2>/dev/null | grep -o "imageURLs:\[.*\]" | head -1 | \
      sed "s/imageURLs:\[//;s/\].*//;s/'//g" | tr ',' '\n' | sort -u | \
      while read img; do
        if [ -n "$img" ]; then
          echo "${BASE}/${img}"
        fi
      done | paste -sd',' -)
    if [ -n "$flash2" ]; then
      flash="${flash},${flash2}"
    fi
  fi

  # Method 4: Check for fotos page linked differently (e.g. FOTOS-CAVE-NAME.htm)
  slug=$(basename "$url" .htm)
  alt_photo="$BASE/FOTOS-${slug}.htm"
  flash3=$(curl -s --max-time 5 "$alt_photo" 2>/dev/null | grep -o "imageURLs:\[.*\]" | head -1 | \
    sed "s/imageURLs:\[//;s/\].*//;s/'//g" | tr ',' '\n' | sort -u | \
    while read img; do
      if [ -n "$img" ]; then
        echo "${BASE}/${img}"
      fi
    done | paste -sd',' -)
  if [ -n "$flash3" ]; then
    flash="${flash},${flash3}"
  fi

  # Merge all sources
  all_imgs="${inline},${flash}"
  # Remove empty entries and duplicates
  all_imgs=$(echo "$all_imgs" | tr ',' '\n' | grep -v '^$' | sort -u | paste -sd',' -)

  if [ -n "$all_imgs" ]; then
    fname=$(basename "$f")
    count=$(echo "$all_imgs" | tr ',' '\n' | wc -l | tr -d ' ')
    echo "$fname: $count images"

    node -e "
      const fs = require('fs');
      const data = JSON.parse(fs.readFileSync('$f', 'utf8'));
      const newImgs = '${all_imgs}'.split(',').filter(Boolean);
      const existing = data.images || [];
      const merged = [...new Set([...existing, ...newImgs])];
      data.images = merged;
      data.has_photos = merged.length > 0;
      fs.writeFileSync('$f', JSON.stringify(data, null, 2));
    "
  fi
done

echo ""
echo "=== Summary ==="
node -e "
const fs = require('fs');
const files = fs.readdirSync('data').filter(f=>f.endsWith('.json'));
let w=0,wo=0;
files.forEach(f=>{
  const d=JSON.parse(fs.readFileSync('data/'+f,'utf8'));
  if(d.images && d.images.length>0) w++; else wo++;
});
console.log('With images:', w);
console.log('Without images:', wo);
"