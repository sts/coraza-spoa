#!/bin/bash

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  echo "Usage: ${0} <branch> [--push]"
  echo "  branch       The branch or tag to build. Required."
  echo "  --push       Pushes the built Docker image to the registry."
  echo ""
  echo "You can use the following ENV variables to customize the build:"a
  echo "  TAG         The version part of the docker tag."
  echo "              Default:"
  echo "                When <branch>=main:    snapshot"
  echo "                When <branch>=docker:  latest"
  echo "                Else:                  same as <branch>"
  echo "  DOCKER_REGISTRY The Docker repository's registry (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: docker.io"
  echo "  DOCKER_ORG  The Docker repository's organisation (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: corazawaf"
  echo "  DOCKER_REPO The Docker repository's name (i.e. '\${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}'')"
  echo "              Used for tagging the image."
  echo "              Default: coraza-spoa"
  echo "  DOCKER_TAG  The name of the tag which is applied to the image."
  echo "              Useful for pushing into another registry than hub.docker.com."
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:\${TAG}"
  echo "  DOCKER_SHORT_TAG The name of the short tag which is applied to the"
  echo "              image. This is used to tag all patch releases to their"
  echo "              containing version e.g. v2.5.1 -> v2.5"
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:<MAJOR>.<MINOR>"
  echo "  DOCKERFILE  The name of Dockerfile to use."
  echo "              Default: Dockerfile"
  echo "  BUILDX_PLATFORMS"
  echo "            Specifies the platform(s) to build the image for."
  echo "            Example: 'linux/amd64,linux/arm64'"
  echo "            Default: 'linux/amd64'"
  echo "  CORERULESET_VERSIONS A space separated list of coreruleset version tags."
  echo "              Default: 3.3.2 4.0.0-rc1"
  echo "  DRY_RUN     Prints all build statements instead of running them."
  echo "              Default: undefined"
  echo "Examples:"
  echo "  ${0} main"
  echo "              This will fetch the latest 'main' branch, build a Docker Image and tag it"
  echo "              'corazawaf/coraza-spoa:snapshot'."
  echo "  ${0} docker"
  echo "              This will fetch the latest 'develop' branch, build a Docker Image and tag it"
  echo "              'corazawaf/coraza-spoa:latest'."
  echo "  ${0} v2.6.6"
  echo "              This will fetch the 'v2.6.6' tag, build a Docker Image and tag it"
  echo "              'corazawaf/coraza-spoa:v2.6.6' and 'corazawaf/coraza-spoa:v2.6'."
  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi

if [ -z "${DRY_RUN}" ]; then
  DRY=""
else
  echo "⚠️ DRY_RUN MODE ON ⚠️"
  DRY="echo"
fi

BRANCH="${1}"
BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M+00:00')"

if [ -d ".git" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi


DOCKER_REGISTRY="${DOCKER_REGISTRY-docker.io}"
DOCKER_ORG="${DOCKER_ORG-corazawaf}"
DOCKER_REPO="${DOCKER_REPO-coraza-spoa}"

case "${BRANCH}" in
master|main)
  TAG="${TAG-snapshot}"
  ;;
docker)
  TAG="${TAG-latest}"
  ;;
*)
  TAG="${TAG-$BRANCH}"
  ;;
esac

###
# Determining the value for DOCKERFILE
# and checking whether it exists
###
DOCKERFILE="${DOCKERFILE-docker/coraza-spoa/Dockerfile}"
if [ ! -f "${DOCKERFILE}" ]; then
  echo "🚨 The Dockerfile ${DOCKERFILE} doesn't exist."
fi

CORERULESET_VERSIONS="${CORERULESET_VERSIONS-3.3.2 4.0.0-rc1}"

DEFAULT_DOCKER_TARGETS=("main" "coreruleset")
DOCKER_TARGETS=("${DOCKER_TARGET:-"${DEFAULT_DOCKER_TARGETS[@]}"}")
echo "🏭 Building the following targets:" "${DOCKER_TARGETS[@]}"

for DOCKER_TARGET in "${DOCKER_TARGETS[@]}"; do
    echo "🏗  Building the target '${DOCKER_TARGET}'"

    TARGET_DOCKER_TAG="${DOCKER_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:${TAG}}"
    if [ "${DOCKER_TARGET}" != "main" ]; then
      TARGET_DOCKER_TAG="${TARGET_DOCKER_TAG}-${DOCKER_TARGET}"
    fi

    TARGET_DOCKER_TAG_PROJECT="${TARGET_DOCKER_TAG}-${PROJECT_VERSION}"

    ###
    # composing the additional DOCKER_SHORT_TAG,
    # i.e. "v2.6.1" becomes "v2.6",
    # which is only relevant for version tags
    # Also let "latest" follow the highest version
    ###
    if [[ "${TAG}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
      MAJOR=${BASH_REMATCH[1]}
      MINOR=${BASH_REMATCH[2]}

      TARGET_DOCKER_SHORT_TAG="${DOCKER_SHORT_TAG-${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:v${MAJOR}.${MINOR}}"
      TARGET_DOCKER_LATEST_TAG="${DOCKER_REGISTRY}/${DOCKER_ORG}/${DOCKER_REPO}:latest"

      if [ "${DOCKER_TARGET}" != "main" ]; then
        TARGET_DOCKER_SHORT_TAG="${TARGET_DOCKER_SHORT_TAG}-${DOCKER_TARGET}"
        TARGET_DOCKER_LATEST_TAG="${TARGET_DOCKER_LATEST_TAG}-${DOCKER_TARGET}"
      fi

      TARGET_DOCKER_SHORT_TAG_PROJECT="${TARGET_DOCKER_SHORT_TAG}-${PROJECT_VERSION}"
      TARGET_DOCKER_LATEST_TAG_PROJECT="${TARGET_DOCKER_LATEST_TAG}-${PROJECT_VERSION}"
    fi

    DOCKER_BUILD_ARGS=(
        -f "${DOCKERFILE}"
        --target="${DOCKER_TARGET}"
        --label "org.label-schema.build-date=${BUILD_DATE}"
        --label "org.opencontainers.image.created=${BUILD_DATE}"
        --label "org.opencontainers.image.url=https://coraza.io"
        --label "org.opencontainers.image.documentation=https://github.com/corazawaf/coraza-spoa/"
        --label "org.opencontainers.image.source=https://github.com/corazawaf/coraza-spoa.git"
        --label "org.opencontainers.image.vendor=Coraza"
        --label "org.opencontainers.image.licenses=Apache-2.0"
    )
    DOCKER_BUILD_ARGS+=(--platform "${BUILDX_PLATFORM-linux/amd64,linux/arm64}")


    if [ -d ".git" ]; then
      DOCKER_BUILD_ARGS+=(
        --label "org.label-schema.vcs-ref=${GIT_REF}"
        --label "org.opencontainers.image.revision=${GIT_REF}"
      )
    fi

    if [ "${2}" == "--push" ]; then
      # output type=docker does not work with pushing
      DOCKER_BUILD_ARGS+=(
        --output=type=image
        --push
      )
    else
      DOCKER_BUILD_ARGS+=(
        --output=type=docker
      )
    fi

    if [ "${DOCKER_TARGET}" == "coreruleset" ] ; then
        for CORERULESET_VERSION in $CORERULESET_VERSIONS ; do
            CRS_TARGET_DOCKER_TAG="${TARGET_DOCKER_TAG}-crs${CORERULESET_VERSION}"

            CRS_DOCKER_BUILD_ARGS+=(
              ${DOCKER_BUILD_ARGS[@]}
              -t "${CRS_TARGET_DOCKER_TAG}"
            )

            echo "🐳 Building the Docker image (coreruleset ${CORERULESET_VERSION})"

            $DRY docker buildx build "${CRS_DOCKER_BUILD_ARGS[@]}" --build-arg "CORERULESET_VERSION=${CORERULESET_VERSION}" .
            unset CRS_DOCKER_BUILD_ARGS
        done

    else
        echo "🐳 Building the Docker image"

        NONCRS_DOCKER_BUILD_ARGS=(
          ${DOCKER_BUILD_ARGS[@]}
          -t "${TARGET_DOCKER_TAG}"
        )

        $DRY docker buildx build "${NONCRS_DOCKER_BUILD_ARGS[@]}" .
    fi

    unset DOCKER_BUILD_ARGS

done
