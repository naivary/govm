# upgrade ubuntu
sudo -i apt-get upgrade -y && sudo -i apt-get update

# adding user "${OS_USERNAME}" with root-priviliges
# with the password $OS_PASSWORD, without typing
# the password every type running a sudo
# adduseradduser --gecos "" "${OS_USERNAME}"
useradd -m -p ${OS_PASSWORD} -s /bin/bash ${OS_USERNAME}
sudo chown ${OS_USERNAME}:${OS_USERNAME} /home/${OS_USERNAME}
usermod -aG sudo "${OS_USERNAME}"

echo "${OS_USERNAME}:${OS_PASSWORD}" | sudo chpasswd
passwd --expire "${OS_USERNAME}";

cat << EOF > "/etc/sudoers.d/${OS_USERNAME}"
${OS_USERNAME} ALL = (ALL) NOPASSWD:ALL
EOF

chmod 0400 "/etc/sudoers.d/${OS_USERNAME}"

# helpful tools
apt install git -y;
apt install net-stat -y;
apt install traceroute;


# setup firewall
sudo ufw default deny incoming;
sudo ufw default allow outgoing;
sudo ufw allow ssh;
sudo ufw allow http;
sudo ufw allow https;
echo "y" | sudo ufw enable; 

# create custome terminal-prompt
cat << EOF > "/home/${OS_USERNAME}/.bash_profile"
export PS1="<\!>\u@\h:\w>"
EOF

sudo -u ${OS_USERNAME} cat << EOF > "/home/${OS_USERNAME}/.git-credentials"
https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com
EOF


#create .gitconfig 
touch /home/${OS_USERNAME}/.gitconfig
sudo chown ${OS_USERNAME}:${OS_USERNAME} /home/${OS_USERNAME}/.gitconfig
sudo -i -u "${OS_USERNAME}" git config --global user.email "${GIT_EMAIL}"
sudo -i -u "${OS_USERNAME}" git config --global user.name "${GIT_NAME}"
sudo -i -u "${OS_USERNAME}" git config --global credential.helper "store --file ~/.git-credentials"
sudo -i -u "${OS_USERNAME}" git config --global alias.aa "add --all"
sudo -i -u "${OS_USERNAME}" git config --global alias.bv "branch -v"
sudo -i -u "${OS_USERNAME}" git config --global alias.ba "branch -ra"
sudo -i -u "${OS_USERNAME}" git config --global alias.bd "branch -d"
sudo -i -u "${OS_USERNAME}" git config --global alias.ca "commit --amend"
sudo -i -u "${OS_USERNAME}" git config --global alias.cb "checkout -b"
sudo -i -u "${OS_USERNAME}" git config --global alias.cm "commit -a --amend -C HEAD"
sudo -i -u "${OS_USERNAME}" git config --global alias.ci "commit -a -v"
sudo -i -u "${OS_USERNAME}" git config --global alias.co "checkout"
sudo -i -u "${OS_USERNAME}" git config --global alias.di "diff"
sudo -i -u "${OS_USERNAME}" git config --global alias.lo "log"
sudo -i -u "${OS_USERNAME}" git config --global alias.mm "merge --no-ff"
sudo -i -u "${OS_USERNAME}" git config --global alias.st "status --short --branch"
sudo -i -u "${OS_USERNAME}" git config --global alias.tg "tag -a"
sudo -i -u "${OS_USERNAME}" git config --global alias.pu "push --tags"
sudo -i -u "${OS_USERNAME}" git config --global alias.uh "reset --hard HEAD"
sudo -i -u "${OS_USERNAME}" git config --global alias.ll "log --pretty=format:\"%C\(yellow\)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn\]\" --decorate --numstat"
sudo -i -u "${OS_USERNAME}" git config --global alias.ld "log --pretty=format:\"%C(yellow)%h\\ %C(green)%ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=short --graph"
sudo -i -u "${OS_USERNAME}" git config --global alias.ls "log --pretty=format:\"%C(green)%h\\ %C(yellow)[%ad]%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=relative"

sudo -i -u ${OS_USERNAME} git clone https://github.com/No1Lik3U/Testing.git /home/${OS_USERNAME}/testing;
cat << EOF > "/home/${OS_USERNAME}/testing/README.md"
success!
EOF
sudo -i -u ${OS_USERNAME} git -C /home/${OS_USERNAME}/testing add .;
sudo -i -u ${OS_USERNAME} git -C /home/${OS_USERNAME}/testing commit -m "it worked";
sudo -i -u ${OS_USERNAME} git -C /home/${OS_USERNAME}/testing push -u origin master;

if [ "$?" -ne 1 ]; then
  echo "Git credentials are wrong!"
fi

sudo -i -u ${OS_USERNAME} rm -r /home/${OS_USERNAME}/testing

