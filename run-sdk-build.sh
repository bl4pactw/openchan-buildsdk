#!/bin/bash

if ! groups $(whoami) | grep -q "\bdocker\b"; then
    echo "Error: Current user is not in the 'docker' group. Please add the user to the 'docker' group with the following command:"
    echo "sudo usermod -aG docker $(whoami)"
    echo "After that, log out and log back in for the group changes to take effect."
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <container_name> [<input: image_name>]"
    exit 1
fi

container_name="$1"
input_image_name="$2"

if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    echo "Container \"$container_name\" already exists. Starting it..."
    docker start "$container_name"
else

    if [ -n "$input_image_name" ]; then
        
        if docker images --format '{{.Repository}}' | grep -q "^$input_image_name$"; then
            echo "Image \"$input_image_name\" found. Creating and starting a new container..."
            docker run -it -v "$(pwd):/home/$(id -un)/repo" -d --name "$container_name" "$input_image_name" /bin/bash
        else
	    echo "Error: Container $container_name not found."
            echo "Error: Image $input_image_name not found."
	    echo "Listing available images:"
            docker images
            exit 1
        fi

    else
        echo "Error: No image provided. Container \"$container_name\" will not be created."
        echo "Available Docker images:"
        docker images
        exit 1
    fi

fi

docker exec -it --user "$(id -un)" "$container_name" /bin/bash

