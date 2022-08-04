echo "Delete .env if it already exists"
rm .env >> /dev/null 2>&1

echo "Writing arguments to .env"
for arg in "$@"
do
	echo "${arg}" >> .env
done

echo "Finished, .env file created."