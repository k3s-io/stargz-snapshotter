#!/bin/bash

#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail

NODE_TEST_IMAGE_NAME="cri-integration-node-testimage"
CONTAINERD_SOCK=unix:///run/containerd/containerd.sock

IMAGE_LIST="${1}"

TEST_NODE_ID=$(docker run --rm -d --privileged \
                      -v /dev/fuse:/dev/fuse \
                      --tmpfs=/var/lib/containerd:suid \
                      --tmpfs=/var/lib/containerd-stargz-grpc:suid \
                      "${NODE_TEST_IMAGE_NAME}")
echo "Running node on: ${TEST_NODE_ID}"
FAIL=
for i in $(seq 100) ; do
    if docker exec -i "${TEST_NODE_ID}" ctr version ; then
        break
    fi
    echo "Fail(${i}). Retrying..."
    if [ $i == 100 ] ; then
        FAIL=true
    fi
    sleep 1
done

# If container started successfully, varidate the runtime through CRI
if [ "${FAIL}" == "" ] ; then
    if ! docker exec -i "${TEST_NODE_ID}" /go/bin/critest --runtime-endpoint=${CONTAINERD_SOCK} ; then
        FAIL=true
    fi
fi

# Dump all names of images used in the test
docker exec -i "${TEST_NODE_ID}" journalctl -xu containerd \
    | grep PullImage | sed -E 's/.*PullImage \\"([^\\]*)\\".*/\1/g' | sort | uniq > "${IMAGE_LIST}"

docker kill "${TEST_NODE_ID}"
if [ "${FAIL}" != "" ] ; then
    exit 1
fi

exit 0
