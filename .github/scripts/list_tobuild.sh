#!/bin/bash
set -xe
git pull origin main || true
git reset --hard origin/main

mkdir -p lists/auto
touch tobuild.txt
if [ ! -s tobuild.txt ]; then
      # Get all packages with no deps in the working list
      # Make a file with "readytobuild" for each path lists/{pkg}
      grep -Pzo "(?s)\s*\"\N*\":\s*\[\s*\]" packages.json | awk -F'"' '{print $2}' | grep -v '^$' | xargs -i bash -c 'touch lists/{} && if ! [ -s "lists/failed/{}" ]; then if ! [ -s "lists/{}" ]; then echo "readytobuild" > lists/{}; else if grep -q "tar.gz$" lists/{}; then bash -c "mv lists/{} lists/auto/ && echo readytobuild > lists/{}"; fi; fi; fi'

      # Add list of packages to build
      grep -lr "readytobuild" lists/ | sed 's#lists/##g' > tobuild.txt

      if [ ! -s tobuild.txt ] && [ -f "packages.json" ]; then
            mkdir -p logs/$(cat runstarttime)
            counter=0
            if [ -f "logs/$(cat runstarttime)/retries_counter" ]; then
                counter=$(<logs/$(cat runstarttime)/retries_counter)
            fi
            counter=$((counter+1))
            echo $counter > "logs/$(cat runstarttime)/retries_counter"
            if [ $counter -gt 4 ]; then
                grep -Ervl "(failed|tar.gz$)" lists | grep -v "failed" > /tmp/resetpkgs || true
                if [ -s /tmp/resetpkgs ]; then
                    cat /tmp/resetpkgs | xargs rm
                    git add lists;
                fi
            fi
            if [ $counter -eq 10 ]; then
                echo "READY" > /tmp/write_PACKAGES
            fi
            git add logs/$(cat runstarttime)
            git commit -m "Increment counter for empty tobuild lists"
      else
            if [ -f "logs/$(cat runstarttime)/retries_counter" ]; then
                rm logs/$(cat runstarttime)/retries_counter
                git add logs/$(cat runstarttime)
            fi
            git add lists
            git add tobuild.txt
            git commit -m "Adding tobuild list"
      fi
      git push
fi
