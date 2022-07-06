#!/usr/bin/env zsh

if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

export PATH="/opt/homebrew/opt/mariadb@10.3/bin:$PATH"
