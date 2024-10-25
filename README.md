# github-repo

Test for using Docker to build the QuecOpen SDK.

- Usage: ./new-sdk-build.sh <output: image_name> <input: dockerfile_path>
  - <output: image_name>
  - <input: dockerfile_path>
```
$ ./new-sdk-build.sh sdx7-open-img dockerfile-quecopen-sdx7x
```

- Usage: ./run-sdk-build.sh <container_name> [<input: image_name>]
  - <container_name>
  - (Option) <input: image_name>
```
# Run a new container:
$ ./run-sdk-build.sh sdx7-open sdx7-open-img

# Run an exsting container:
$ ./run-sdk-build.sh sdx7-open 
```
