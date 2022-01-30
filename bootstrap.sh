# upgrade ubuntu
sudo -i apt-get upgrade -y && sudo -i apt-get update

# adding user musti with root-priviliges
# with the password 20Himmel20, without typing
# the password every type running a sudo
adduser --gecos "" musti
usermod -aG sudo musti

echo "musti:20Himmel20" | sudo chpasswd

cat << EOF > /etc/sudoers.d/musti
musti ALL = (ALL) NOPASSWD:ALL
EOF

chmod 0400 /etc/sudoers.d/musti

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
cat << EOF > /home/musti/.bash_profile
export PS1="<\!>\u@\h:\w>"
EOF

cat << EOF > /home/musti/.git-credentials
https://No1Lik3U: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@github.com
EOF

#create git-config
sudo -i -u musti git config --global credential.helper "store --file ~/.git-credentials"
sudo -i -u musti git config --global alias.aa "add --all"
sudo -i -u musti git config --global alias.bv "branch -v"
sudo -i -u musti git config --global alias.ba "branch -ra"
sudo -i -u musti git config --global alias.bd "branch -d"
sudo -i -u musti git config --global alias.ca "commit --amend"
sudo -i -u musti git config --global alias.cb "checkout -b"
sudo -i -u musti git config --global alias.cm "commit -a --amend -C HEAD"
sudo -i -u musti git config --global alias.ci "commit -a -v"
sudo -i -u musti git config --global alias.co "checkout"
sudo -i -u musti git config --global alias.di "diff"
sudo -i -u musti git config --global alias.lo "log"
sudo -i -u musti git config --global alias.mm "merge --no-ff"
sudo -i -u musti git config --global alias.st "status --short --branch"
sudo -i -u musti git config --global alias.tg "tag -a"
sudo -i -u musti git config --global alias.pu "push --tags"
sudo -i -u musti git config --global alias.uh "reset --hard HEAD"
sudo -i -u musti git config --global alias.ll "log --pretty=format:\"%C\(yellow\)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn\]\" --decorate --numstat"
sudo -i -u musti git config --global alias.ld "log --pretty=format:\"%C(yellow)%h\\ %C(green)%ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=short --graph"
sudo -i -u musti git config --global alias.ls "log --pretty=format:\"%C(green)%h\\ %C(yellow)[%ad]%Cred%d\\ %Creset%s%Cblue\\ [%cn]\" --decorate --date=relative"
