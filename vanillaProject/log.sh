#A simple script to get the Docker peer log

#get machine name:
H=$(hostnamectl status --static)
h=${H,,} #lower-case version

#get Docker log location:
logLoc=$(docker inspect --format='{{.LogPath}}' peer0.${h}.scm.com)

#copy log and change permissions to current user:
sudo cp $logLoc peer.log && sudo chown $(whoami) peer.log
