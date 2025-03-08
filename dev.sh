#!/usr/bin/env bash

#BIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
#
#BASE_DIR="$BIN_DIR/.."

# BEGIN: Pre-defined variables
if [ -z "$BASE_DIR" ]; then
    BASE_DIR="$PWD"
fi

if [ -f "$BASE_DIR/custom.sh" ]; then
    source "$BASE_DIR/custom.sh"
fi

if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME=$(basename "$BASE_DIR")
fi

if [ -z "$NODE_VERSION" ]; then
    NODE_VERSION='20'
fi

if [ -z "$PHP_VERSION" ]; then
    PHP_VERSION='8.4'
fi

if [ -z "$DOCKER_CR" ]; then
    DOCKER_CR='ghcr.io'
fi

if [ -z "$DOCKER_ORG" ]; then
    DOCKER_ORG='seriquynh'
fi

if [ -z "$DOCKER_IMAGE" ]; then
    DOCKER_IMAGE="$SERVICE_NAME"
fi

if [ "$BRANCH_NAME" = 'main' ]; then
    DOCKER_TAG='latest'
else
    DOCKER_TAG="dev"
fi

if [ -z "$DEPLOY_SSH_HOST" ]; then
    DEPLOY_SSH_HOST='app-server'
fi

if [ -z "$DEPLOY_SERVICE_DIR" ]; then
    DEPLOY_SERVICE_DIR="/home/forge/$SERVICE_NAME"
fi

if [ -z "$DEPLOY_RELEASE_MAX" ]; then
    DEPLOY_RELEASE_MAX=3
fi

if [[ "$BRANCH_NAME" == bug* ]] || [[ "$BRANCH_NAME" == feature* ]]; then
    DEPLOY_DIR="$DEPLOY_SERVICE_DIR/dev"
elif [ "$BRANCH_NAME" == 'develop' ]; then
    DEPLOY_DIR="$DEPLOY_SERVICE_DIR/staging"
elif [ "$BRANCH_NAME" == 'main' ]; then
    DEPLOY_DIR="$DEPLOY_SERVICE_DIR/production"
else
    DEPLOY_DIR="$DEPLOY_SERVICE_DIR/dev"
fi

HASH=$(git rev-parse HEAD)
PACKAGED_DIR="$BASE_DIR/docker/app/packaged"
APP_USER_ID=$(id -u)
APP_GROUP_ID=$(id -g)
# END: Pre-defined variables

DOCKER_COMPOSE="docker compose -f $BASE_DIR/docker/docker-compose.yml"

# If it's running on CI (e.g. Jenkins CI)
if [ "$BUILD_NUMBER" != '' ]; then
    DOCKER_COMPOSE="$DOCKER_COMPOSE -f $BASE_DIR/docker/docker-compose.ci.yml"
    TTY='-T'
# Otherwise, it's running on local
else
    if [ -f "$BASE_DIR/docker/docker-compose.local.yml" ]; then
        DOCKER_COMPOSE="$DOCKER_COMPOSE -f $BASE_DIR/docker/docker-compose.local.yml"
    fi
    TTY='-it'
fi

# Begin: helper functions
helper_print_error() {
    echo "  [ERROR]: $1"
}

helper_print_warning() {
    echo "  [WARNING]: $1"
}

helper_print_info() {
    echo "  [INFO]: $1"
}

helper_print_line() {
    echo "    $1"
}

helper_fix_owner() {
    for _ITEM in node_modules public/build vendor
    do
        if [ -d "$1/$_ITEM" ] || [ -f "$1/$_ITEM" ]; then
            docker run --rm -v "$1:/opt" -w /opt ubuntu:24.04 chown -R "$APP_USER_ID:$APP_GROUP_ID" "$_ITEM"
        fi
    done
}

helper_copy() {
    helper_print_line "Copy $1 to $2"

    cp "$1" "$2"
}

helper_remove() {
    if [ -d "$1" ]; then
        helper_print_line "Removing: $1"

        rm -rf "$1"

        if [ -d "$1" ]; then
            helper_print_line "Failed: $1 still exist."

            return 1
        else
            helper_print_line "Removed: $1"

            return 0
        fi
    elif [ -f "$1" ]; then
        helper_print_line "Removing: $1"

        rm -f "$1"

        if [ -f "$1" ]; then
            helper_print_line "Failed: $1 still exist."

            return 1
        else
            helper_print_line "Removed: $1"

            return 0
        fi
    else
        helper_print_line "Ignored: $1 does NOT exist."
    fi
}

helper_composer_install() {
    helper_print_info "Try loading composer dependencies from cache."

    if [ -f "$1/composer.lock" ]; then
        local _COMPOSER_LOCK_HASH=$(sha1sum "$1/composer.lock" | awk '{print $1}')

        local _CACHE_DIR="$HUDSON_HOME/custom/composer/cache-$_COMPOSER_LOCK_HASH"

        if [ -d "$_CACHE_DIR" ]; then
            helper_print_info "Composer dependencies are loaded from $_CACHE_DIR."

            cp -a "$_CACHE_DIR" "$1/vendor"
        else
            helper_print_info "$_CACHE_DIR does not exist."
        fi
    else
        helper_print_warning "$1 does not contain a composer.lock file"
    fi
}

helper_composer_cache() {
    helper_print_info "Create $HUDSON_HOME/custom/composer directory if it does not exist."

    mkdir -p "$HUDSON_HOME/custom/composer"

    local _COMPOSER_LOCK_HASH=$(sha1sum "$1/composer.lock" | awk '{print $1}')

    local _CACHE_DIR="$HUDSON_HOME/custom/composer/cache-$_COMPOSER_LOCK_HASH"

    if [ ! -d "$_CACHE_DIR" ]; then
        helper_print_info "Write cache to $_CACHE_DIR"
        cp -a "$1/vendor" "$_CACHE_DIR"
    else
        helper_print_info "$_CACHE_DIR already exists."
    fi
}

helper_npm_install() {
    helper_print_info "Try loading NPM packages from cache."

    if [ -f "$1/package-lock.json" ]; then
        local _NPM_LOCK_HASH=$(sha1sum "$1/package-lock.json" | awk '{print $1}')

        local _CACHE_DIR="$HUDSON_HOME/custom/npm/cache-$_NPM_LOCK_HASH"

        if [ -d "$_CACHE_DIR" ]; then
            helper_print_info "NPM packages are loaded from $_CACHE_DIR."

            cp -a "$_CACHE_DIR" "$1/node_modules"
        else
            helper_print_info "$_CACHE_DIR does not exist."
        fi
    else
        helper_print_warning "$1 does not contain a package-lock.json file"
    fi
}

helper_npm_cache() {
    helper_print_info "Create $HUDSON_HOME/custom/npm directory if it does not exist."

    mkdir -p "$HUDSON_HOME/custom/npm"

    local _NPM_LOCK_HASH=$(sha1sum "$1/package-lock.json" | awk '{print $1}')

    local _CACHE_DIR="$HUDSON_HOME/custom/npm/cache-$_NPM_LOCK_HASH"

    if [ ! -d "$_CACHE_DIR" ]; then
        helper_print_info "Write cache to $_CACHE_DIR"
        cp -a "$1/node_modules" "$_CACHE_DIR"
    else
        helper_print_info "$_CACHE_DIR already exists."
    fi
}

helper_release_name() {
    if [ ! -f "$BASE_DIR/release.txt" ]; then
        date +"%Y%m%d%H%M%S" > "$BASE_DIR/release.txt"
    fi

    cat "$BASE_DIR/release.txt"
}

helper_release_dir() {
    echo "$DEPLOY_DIR/releases/$(helper_release_name)"
}

helper_release_artisan() {
    echo "php$PHP_VERSION $DEPLOY_DIR/releases/$(helper_release_name)/artisan"
}
# End: helper functions

# Begin: ci_*
ci_clean_images() {
    helper_print_info 'Remove docker dangling images.'

    _DANLING_IMAGES=$(docker images -q --filter "dangling=true")

    if [ -n "$_DANLING_IMAGES" ]; then
        docker rmi "$_DANLING_IMAGES"
    else
        helper_print_line "There are no images to remove."
    fi
}

ci_clean_volumes() {
    helper_print_info 'Remove docker temporary volumes.'

    _VOLUMES=$(docker volume ls -q | grep "${SERVICE_NAME}_${BRANCH_NAME}")

    if [ -n "$_VOLUMES" ]; then
        docker volume rm "$_VOLUMES"
    else
        helper_print_line "There are no volumes to remove."
    fi
}

ci_clean_workspace() {
    helper_print_info 'Remove runtime files.'

    for _RUNTIME_FILE in .env .env.local .env.testing .env.production .npmrc auth.json release.txt
    do
        helper_remove "$BASE_DIR/$_RUNTIME_FILE"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done

    helper_print_info 'Remove runtime directories.'

    for _RUNTIME_DIR in docker/app/packaged node_modules vendor
    do
        helper_remove "$BASE_DIR/$_RUNTIME_DIR"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done
}
# End: ci_*

# Begin: package_*
package_init() {
    package_remove

    package_create

    package_clone

    package_hash

    package_prepare
}

package_remove() {
    helper_print_info "Remove $PACKAGED_DIR"

    helper_remove "$PACKAGED_DIR"
}

package_create() {
    helper_print_info "Create $PACKAGED_DIR"

    mkdir -p "$PACKAGED_DIR"
}

package_clone() {
    helper_print_info "Clone code into $PACKAGED_DIR"

    git archive --format=tar --worktree-attributes "$HASH" | tar -xf -  -C "$PACKAGED_DIR"
}

package_hash() {
    helper_print_info "Create $PACKAGED_DIR/hash.txt"

    echo "$HASH" > "$PACKAGED_DIR/hash.txt"
}

package_prepare() {
    helper_print_info "Prepare .env, .npmrc and auth.json in $PACKAGED_DIR"

    if [ -f "$BASE_DIR/.env.example" ]; then
        helper_copy "$BASE_DIR/.env.example" "$PACKAGED_DIR/.env"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi

    if [ -f "$BASE_DIR/.npmrc" ]; then
        helper_copy "$BASE_DIR/.npmrc" "$PACKAGED_DIR/.npmrc"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi

    if [ -f "$BASE_DIR/auth.json" ]; then
        helper_copy "$BASE_DIR/auth.json" "$PACKAGED_DIR/auth.json"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
}

package_composer() {
    local _COMMAND="$1"

    if [ "$_COMMAND" = 'install' ]; then
        helper_composer_install "$PACKAGED_DIR"

        if [ -d "$PACKAGED_DIR/vendor" ]; then
            exit 0
        fi
    fi

    docker run --rm -w /opt -v "$PACKAGED_DIR:/opt" "composer:2" composer "$@"

    if [ $? -ne 0 ]; then
        exit 1
    fi

    helper_fix_owner "$PACKAGED_DIR"

    if [ "$_COMMAND" = 'install' ]; then
        helper_composer_cache "$PACKAGED_DIR"
    fi
}

package_npm() {
    local _COMMAND="$1"

    if [ "$_COMMAND" = 'install' ] || [ "$_COMMAND" = 'ci' ]; then
        helper_npm_install "$PACKAGED_DIR"

        if [ -d "$PACKAGED_DIR/node_modules" ]; then
            exit 0
        fi
    fi

    docker run --rm -w /opt -v "$PACKAGED_DIR:/opt" "node:$NODE_VERSION" npm "$@"

    if [ $? -ne 0 ]; then
        exit 1
    fi

    helper_fix_owner "$PACKAGED_DIR"

    if [ "$_COMMAND" = 'install' ] || [ "$_COMMAND" = 'ci' ]; then
        helper_npm_cache "$PACKAGED_DIR"
    fi
}

package_clean() {
    helper_print_info 'Remove unnecessary directories and files before building package.'

    for _SUBDIR in docker node_modules tests
    do
        helper_remove "$PACKAGED_DIR/$_SUBDIR"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done

    for _FILE in .editorconfig .env.ci .env.example .gitattributes .gitignore .npmrc .prettierrc auth.json eslint.config.js Jenkinsfile jsconfig.json package.json package-lock.json phpunit.xml.dist postcss.config.js README.md tailwind.config.js vite.config.js
    do
        helper_remove "$PACKAGED_DIR/$_FILE"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done
}

package_build() {
    # TODO: [1] Check if DOCKER_ORG AND DOCKER_TAG exist.

    docker build "$BASE_DIR/docker/app" --target production -t "$DOCKER_CR/$DOCKER_ORG/$DOCKER_IMAGE:$DOCKER_TAG"
}

package_publish() {
    # TODO: [1] Check if DOCKER_ORG AND DOCKER_TAG exist.

    docker push "$DOCKER_CR/$DOCKER_ORG/$DOCKER_IMAGE:$DOCKER_TAG"
}
# End: package_*

# Begin: deploy_*
deploy_prepare() {
    helper_print_info "[remote] Prepare $DEPLOY_DIR."

    ssh "$DEPLOY_SSH_HOST" "
    if [ ! -d $DEPLOY_DIR ]
    then
        mkdir -p ""$DEPLOY_DIR""
    fi

    if [ ! -d $DEPLOY_DIR/releases ]
        then
            mkdir -p ""$DEPLOY_DIR/releases""
        fi

    if [ ! -d $DEPLOY_DIR/shared ]
    then
        mkdir -p ""$DEPLOY_DIR/shared""
    fi

    if [ ! -d $DEPLOY_DIR/shared/storage ]
    then
        mkdir -p ""$DEPLOY_DIR/shared/storage/app/{private,public}""
        mkdir -p ""$DEPLOY_DIR/shared/storage/framework/{cache,sessions,views}""
        mkdir -p ""$DEPLOY_DIR/shared/storage/logs""
    fi

    if [ ! -f $DEPLOY_DIR/shared/.env ]
    then
        touch ""$DEPLOY_DIR/shared/.env""
    fi
"
}

deploy_upload() {
    helper_print_info "[remote] Upload the package to $(helper_release_dir)."

    scp -r "$PACKAGED_DIR" "$DEPLOY_SSH_HOST:$(helper_release_dir)"

    # TODO: Check if it's failed to upload package.
}

deploy_shared() {
    helper_print_info "[remote] Create symlinks for the storage directory and dotenv file in $(helper_release_dir)."

    for _ITEM in storage .env
    do
        ssh "$DEPLOY_SSH_HOST" rm -rf "$(helper_release_dir)/$_ITEM"
        ssh "$DEPLOY_SSH_HOST" ln -s "$DEPLOY_DIR/shared/$_ITEM" "$(helper_release_dir)/$_ITEM"

        if [ $? -ne 0 ]; then
            exit 1
        fi
    done
}

deploy_artisan_optimize() {
    helper_print_info "[remote] Run artisan optimize command in $(helper_release_dir)."

    ssh "$DEPLOY_SSH_HOST" "$(helper_release_artisan)" optimize
}

deploy_artisan_storage_link() {
    helper_print_info "[remote] Run artisan storage:link command in $(helper_release_dir)."

    ssh "$DEPLOY_SSH_HOST" "$(helper_release_artisan)" storage:link --force
}

deploy_artisan_migrate() {
    helper_print_info "[remote] Run artisan migrate command in $(helper_release_dir)."

    ssh "$DEPLOY_SSH_HOST" "$(helper_release_artisan)" migrate --force
}

deploy_current() {
    helper_print_info "[remote] Change the current symlink to $(helper_release_dir)."

    ssh "$DEPLOY_SSH_HOST" "
        rm -rf ""$DEPLOY_DIR/current"" && ln -s ""$DEPLOY_DIR/releases/$(helper_release_name) $DEPLOY_DIR/current""
    "

    # TODO: Check if it's failed to change the current symlink.
}

deploy_restart_php_fpm() {
    helper_print_info "[remote] Restart PHP $PHP_VERSION FPM."

    ssh "$DEPLOY_SSH_HOST" "sudo systemctl restart php$PHP_VERSION-fpm"
}

deploy_clean() {
    helper_print_info '[remote] Remove stale releases.'

    _RELEASE_COUNT=$(ssh "$DEPLOY_SSH_HOST" "ls $DEPLOY_DIR/releases" | wc -l)

    if [ "$_RELEASE_COUNT" -gt "$DEPLOY_RELEASE_MAX" ]
    then
        _DEL_MAX="$((_RELEASE_COUNT - DEPLOY_RELEASE_MAX))"
        _DEL_COUNT=0

        for _RELEASE_ITEM in $(ssh $DEPLOY_SSH_HOST "ls $DEPLOY_DIR/releases")
        do
            helper_print_line "Removing release: $_RELEASE_ITEM"

            ssh $DEPLOY_SSH_HOST "rm -rf $DEPLOY_DIR/releases/$_RELEASE_ITEM"

            helper_print_line "Removed release: $_RELEASE_ITEM"

            _DEL_COUNT="$((_DEL_COUNT + 1))"

            if [ "$_DEL_COUNT" -eq "$_DEL_MAX" ]; then
                helper_print_line "Total: $_DEL_COUNT"
                exit
            fi
        done
    fi
}
# End: deploy_*

if [ "$1" = 'artisan' ]; then
    shift

    $DOCKER_COMPOSE exec $TTY -e DB_HOST=mysql -e DB_PORT=3306 app artisan "$@"
elif [ "$1" = 'composer' ]; then
    _COMMAND="$2"

    if [ "$_COMMAND" = 'install' ]; then
        helper_composer_install "$BASE_DIR"

        if [ -d "$BASE_DIR/vendor" ]; then
            exit 0
        fi
    fi

    shift

    $DOCKER_COMPOSE exec $TTY -e DB_HOST=mysql -e DB_PORT=3306 app composer "$@"

    if [ "$_COMMAND" = 'install' ]; then
        helper_composer_cache "$BASE_DIR"
    fi
elif [ "$1" = 'mysql' ]; then
    shift

    $DOCKER_COMPOSE exec -it mysql mysql "$@"
elif [ "$1" = 'npm' ]; then
    _COMMAND="$2"

    if [ "$_COMMAND" = 'install' ] || [ "$_COMMAND" = 'ci' ]; then
        helper_npm_install "$BASE_DIR"

        if [ -d "$BASE_DIR/node_modules" ]; then
            exit 0
        fi
    fi

    docker run --rm -v "$BASE_DIR:/opt" -w /opt "node:$NODE_VERSION" "$@"

    if [ $? -ne 0 ]; then
        exit 1
    fi

    helper_fix_owner "$BASE_DIR"

    if [ "$_COMMAND" = 'install' ] || [ "$_COMMAND" = 'ci' ]; then
        helper_npm_cache "$BASE_DIR"
    fi
elif [ "$1" = 'pest' ]; then
    shift

    $DOCKER_COMPOSE exec $TTY -e APP_ENV=testing app ./vendor/bin/pest "$@"
elif [ "$1" = 'phpstan' ]; then
    shift 1

    docker run --rm -v .:/opt seriquynh/laravel-test-runner:latest phpstan "$@"
elif [ "$1" = 'pint' ]; then
    shift 1

    docker run --rm -v .:/opt seriquynh/laravel-test-runner:latest pint "$@"
elif [[ "$1" == ci:* ]] || [[ "$1" == package:* ]] || [[ "$1" == deploy:* ]]; then
    _TASK_GROUP="$(cut -d':' -f1 <<<"$1")"
    _TASK_NAME="$(cut -d':' -f2 <<<"$1")"
    _TASK_FUNCTION="${_TASK_GROUP}_${_TASK_NAME}"

    if declare -F "$_TASK_FUNCTION" > /dev/null; then
        shift

        $_TASK_FUNCTION "$@"
    else
        helper_print_info "Function '$_TASK_FUNCTION' does NOT exist."

        exit 1
    fi
else
    if [ "$1" == 'up' ] || [ "$1" == 'build' ]; then
        APP_USER_ID=$APP_USER_ID \
        APP_GROUP_ID=$APP_GROUP_ID \
            $DOCKER_COMPOSE "$@"
    else
        $DOCKER_COMPOSE "$@"
    fi
fi
