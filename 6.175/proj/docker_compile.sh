CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

rm -rf ./logs/
rm -rf ./bluesim/
docker exec $CID rm -rf /root/6.175_Proj/
docker cp ../proj $CID:/root/6.175_Proj/
docker exec --workdir /root/6.175_Proj $CID make build.bluesim VPROC=THREECYCLE
docker cp $CID:/root/6.175_Proj/bluesim ./bluesim/
