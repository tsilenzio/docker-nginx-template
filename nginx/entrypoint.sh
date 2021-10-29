#!/usr/bin/env bash

# Lock file path and filename
lockFile="/run/lock/entrypoint.lock"

# Remove potential app lock file from previous boot
rm -f $lockFile

function enableLock {
    echo "$$" > $lockFile
}

function disableLock {
    #### Workaround ####
    # For some reason inotifywait runs twice. This workaround will prevent
    # the duplocated event trigger and also from really fast file changes
    #######
    sleep 1 && rm -f $lockFile &
}

# Run cron & nginx
cron &
nginx -g "daemon off;" &

# Watch for nginx conf changes or domains needing SSL certificat generation
#### Workaround ####
# "inotifywait -r --include" doesn't watch new files/dirs. Circumvented
# by using grep to filter for the desired files
#######
inotifywait -e create,modify,delete,move -mrq /app/config/ | grep -E '(\.conf|domains\.txt)$' --line-buffered |
while read -r dir event file
do
    # Prevent running concurrently
    if [[ -f $lockFile ]]; then
        continue
    fi

    enableLock

    # Check if domains.txt was updated
    if [[ "$file" == "domains.txt" ]]; then
        declare -a domains
        declare -a newDomains

        # Convert domains in domains.txt to array
        while IFS= read -r domain
        do
            domains+=($domain)
        done < "/app/config/domains.txt"

        # Build list of domains needing certbot registation
        for domainDir in "${domains[@]}"
        do
            if [[ ! -d "/etc/letsencrypt/live/$domainDir" ]]; then
                newDomains+=($domainDir)
            fi
        done

        # Generate SSL certificate for domains if any are in need
        if [[ ${#newDomains[@]} -gt 0 ]]; then
            nginx -s stop
            RegisterDomains=$(echo "$(echo ${newDomains[@]} | tr ' ' ',' | cat)")
            echo "Detected Domain List Change"
            echo "Executing: certbot certonly --standalone --agree-tos -m "${CERTBOT_EMAIL}" -n -d ${RegisterDomains}"
            certbot certonly --standalone --agree-tos -m "${CERTBOT_EMAIL}" -n -d ${RegisterDomains}
            nginx -g "daemon off;" &
        fi

        disableLock
    else
        # Reload nginx config
        nginx -tq
        if [ $? -eq 0 ]; then
            echo "Detected Nginx Configuration Change"
            echo "Executing: nginx -s reload"
            nginx -s reload
        fi

        disableLock
    fi
done
