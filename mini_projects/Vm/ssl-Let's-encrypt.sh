#!/usr/bin/bash -x

# set default 
domain=

sub-domain=

# start 

sudo su - 
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/${domain}

unlink /etc/nginx/sites-enabled/default

ln -s  /etc/nginx/sites-available/${domain}  /etc/nginx/sites-enabled/${domain}

nginx -t

if [[ $? -eq 0 ]] 
then
echo '****"""""""*** all good so far'
else 
echo '============ error in nginx config ==============='
fi

add_apt_repository ppa:certbot/certbot
apt install python_certbot_nginx
certbot --nginx -d {domain} -d {sub-domain}

