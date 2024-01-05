CID=`docker ps -a| grep kazutoiris/connectal  | awk '{print $1}'`
# echo $CID

rm -rf ./bluesim/
docker exec $CID rm -rf /root/6.375_lab4/
docker cp ../../audio $CID:/root/6.375_lab4/
docker exec --workdir /root/6.375_lab4/connectal $CID make -j8 simulation
docker cp $CID:/root/6.375_lab4/connectal/bluesim ./bluesim/
