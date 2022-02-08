USERNAME=gov
PASSWORD=gov
# upgrade ubuntu
sudo -i apt-get upgrade -y && sudo -i apt-get update

# adding user "${USERNAME}" with root-priviliges
# with the password $PASSWORD, without typing
# the password every type running a sudo
# adduseradduser --gecos "" "${USERNAME}"
useradd -m -p ${PASSWORD} -s /bin/bash ${USERNAME}
sudo chown gov:gov /home/${USERNAME}
usermod -aG sudo "${USERNAME}"

echo "${USERNAME}:${PASSWORD}" | sudo chpasswd
passwd --expire "${USERNAME}";

cat << EOF > "/etc/sudoers.d/${USERNAME}"
${USERNAME} ALL = (ALL) NOPASSWD:ALL
EOF

chmod 0400 "/etc/sudoers.d/${USERNAME}"

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
cat << EOF > "/home/${USERNAME}/.bash_profile"
export PS1="<\!>\u@\h:\w>"
EOF

sudo -u gov cat << EOF > "/home/${USERNAME}/.git-credentials"
https://No1Lik3U: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@github.com
EOF

#create .gitconfig 
touch /home/${USERNAME}/.gitconfig
sudo chown gov:gov /home/${USERNAME}/.gitconfig
sudo -i -u "${USERNAME}" git config --global user.email "SayedMustafaHussaini@outlook.de"
sudo -i -u "${USERNAME}" git config --global user.name "Hussaini"
sudo -i -u "${USERNAME}" git config --global credential.helper "store --file ~/.git-credentials"
sudo -i -u "${USERNAME}" git config --global alias.aa "add --all"
sudo -i -u "${USERNAME}" git config --global alias.bv "branch -v"
sudo -i -u "${USERNAME}" git config --global alias.ba "branch -ra"
sudo -i -u "${USERNAME}" git config --global alias.bd "branch -d"
sudo -i -u "${USERNAME}" git config --global alias.ca "commit --amend"
sudo -i -u "${USERNAME}" git config --global alias.cb "checkout -b"
sudo -i -u "${USERNAME}" git config --global alias.cm "commit -a --amend -C HEAD"
sudo -i -u "${USERNAME}" git config --global alias.ci "commit -a -v"
sudo -i -u "${USERNAME}" git config --global alias.co "checkout"
sudo -i -u "${USERNAME}" git config --global alias.di "diff"
sudo -i -u "${USERNAME}" git config --global alias.lo "log"
sudo -i -u "${USERNAME}" git config --global alias.mm "merge --no-ff"
sudo -i -u "${USERNAME}" git config --global alias.st "status --short --branch"
sudo -i -u "${USERNAME}" git config --global alias.tg "tag -a"
sudo -i -u "${USERNAME}" git config --global alias.pu "push --tags"
sudo -i -u "${USERNAME}" git config --global alias.uh "reset --hard HEAD"
sudo -i -u "${USERNAME}" git config --global alias.ll "log --pretty=format:\"%C\(yellow\)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn\]\" --decorate --numstat"
sudo -i -u "${USERNAME}" git config --global alias.ld "log --pretty=format:\"%C(yellow)%h\\ %C(green)%ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=short --graph"
sudo -i -u "${USERNAME}" git config --global alias.ls "log --pretty=format:\"%C(green)%h\\ %C(yellow)[%ad]%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=relative"

sudo -i -u gov git clone https://github.com/No1Lik3U/Testing.git /home/${USERNAME}/testing;
cat << EOF > "/home/${USERNAME}/testing/README.md"
success!
EOF
sudo -i -u gov git -C /home/${USERNAME}/testing add .;
sudo -i -u gov git -C /home/${USERNAME}/testing commit -m "it worked";
sudo -i -u gov git -C /home/${USERNAME}/testing push -u origin master;

if [ "$?" -ne 0 ]; then
  echo "Git credentials are wrong!"
fi

sudo -i -u gov rm -r /home/${USERNAME}/testing

