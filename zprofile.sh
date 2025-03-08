#!/usr/bin/env bash

if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Node Version Manager
# To run 'nvm' command.
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# JetBrains ToolBox Scripts
# To run 'idea' command.
if [ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]; then
  export PATH="$HOME/Library/Application Support/JetBrains/Toolbox/scripts:$PATH"
fi

# To run 'dev' command.
if [ -f ~/Space/.me/dev.sh ];
then
    alias dev >/dev/null 2>&1

    if [ $? -ne 0 ];
    then
        alias dev="~/Space/.me/dev.sh"
    fi
fi


export GPG_TTY=$(tty)
