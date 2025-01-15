#!/usr/bin/env bash
#
# Cleanup old Docker images, keeping the most recent N images per repo.
# By default, keeps 2. Adjust KEEP_N as needed.

KEEP_N=2

echo "This script will keep the latest $KEEP_N images per repo and remove older ones."
echo "Press Ctrl+C now if you want to abort, or wait 5 seconds..."
sleep 5

# 1) For each repository, list images sorted by creation date desc
# 2) Skip the first $KEEP_N lines
# 3) Remove those older image IDs
# 4) Filter out "<none>" if you consider them unwanted
# (But be cautious with the 'none' images if any are in use)

docker images --format '{{.Repository}} {{.ID}} {{.CreatedAt}}' \
  | sort -k1,1 -k3,3r \
  | awk -v keep="$KEEP_N" '
      {
        repo=$1; id=$2
        # store lines by repo
        arr[repo]=arr[repo] " " id
      }
      END {
        # for each repo, split, keep first K, remove rest
        for (r in arr) {
          split(arr[r], ids, " ");
          # skip empty entry
          count=0
          for (i in ids) {
            if (ids[i] == "") continue
            count++
            if (count > keep) {
              print ids[i]
            }
          }
        }
      }
    ' \
  | while read oldImage; do
      # optional: skip lines that are blank
      if [ -n "$oldImage" ] && [ "$oldImage" != "<none>" ]; then
        echo "Removing old image: $oldImage"
        docker rmi -f "$oldImage"
      fi
    done
