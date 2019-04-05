# Start NTOP docker and connect it to cloudlens0 interface
docker run --name ntop_engine --net=host -t -p 3000:3000 -d lucaderi/ntopng-docker ntopnp -i cloudlens0
