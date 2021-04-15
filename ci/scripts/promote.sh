#!/bin/bash

source $(dirname $0)/common.sh

buildName=$( cat artifactory-repo/build-info.json | jq -r '.buildInfo.name' )
buildNumber=$( cat artifactory-repo/build-info.json | jq -r '.buildInfo.number' )
groupId=$( cat artifactory-repo/build-info.json | jq -r '.buildInfo.modules[0].id' | sed 's/\(.*\):.*:.*/\1/' )
version=$( cat artifactory-repo/build-info.json | jq -r '.buildInfo.modules[0].id' | sed 's/.*:.*:\(.*\)/\1/' )

if [[ $RELEASE_TYPE = "RELEASE" ]]; then
	targetRepo="libs-release-local"
else
	echo "Unknown release type $RELEASE_TYPE" >&2; exit 1;
fi

echo "Promoting ${buildName}/${buildNumber} to ${targetRepo}"

curl \
	-s \
	--connect-timeout 240 \
	--max-time 900 \
	-u ${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD} \
	-H "Content-type:application/json" \
	-d "{\"status\": \"staged\", \"sourceRepo\": \"libs-staging-local\", \"targetRepo\": \"${targetRepo}\"}"  \
	-f \
	-X \
	POST "${ARTIFACTORY_SERVER}/api/build/promote/${buildName}/${buildNumber}" > /dev/null || {
		result=$( curl -s -f -u ${ARTIFACTORY_USERNAME}:${ARTIFACTORY_PASSWORD} "${ARTIFACTORY_SERVER}/api/build/${buildName}/${buildNumber}" )
		resultRepo=$( echo $result | jq -r '.buildInfo.statuses[0].repository' )
		if [[ $resultRepo = "libs-release-local" ]]; then
			echo "Already promoted"
		else
			echo "Failed to promote" >&2
			exit 1
		fi
	}

echo "Promotion complete"
echo $version > version/version